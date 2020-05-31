ROOT ?= $(shell pwd)
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query 'Account' --output text)
LAYER_NAME ?= lambda-layer-cfncli
LAYER_DESC ?= lambda-layer-cfncli
S3BUCKET ?= eduardo-tmp
LAMBDA_REGION ?= us-east-1
LAMBDA_ROLE_ARN ?= arn:aws:iam::$(AWS_ACCOUNT_ID):role/service-role/LambdaDefaultRole
AWS_PROFILE ?= default
PAYLOAD ?= {"foo":"bar"}
DOCKER_MIRROR ?= ''


ifeq ($(shell test -e VERSION && echo -n yes),yes)
    SemanticVersion = $(shell cat VERSION)
endif

ifeq ($(shell test -e envfile && echo -n yes),yes)
	EXTRA_DOCKER_ARGS = --env-file envfile
endif


.PHONY: build layer-build layer-zip layer-upload layer-publish sam-layer-package sam-layer-deploy sam-layer-destroy func-zip create-func update-func func-all layer-all invoke add-layer-version-permission all clean clean-all delete-func 

build: layer-build

layer-build:
	@ DOCKER_MIRROR=$(DOCKER_MIRROR) bash build.sh
	@echo "[OK] Layer built at ./layer.zip"
	@ls -alh ./layer.zip
	
layer-zip:
	( cd layer; zip -r ../layer.zip * )
	
layer-upload:
	@aws --profile=$(AWS_PROFILE) s3 cp layer.zip s3://$(S3BUCKET)/$(LAYER_NAME).zip
	
layer-publish:
	@aws --profile=$(AWS_PROFILE) --region $(LAMBDA_REGION) lambda publish-layer-version \
	--layer-name $(LAYER_NAME) \
	--description $(LAYER_DESC) \
	--license-info "MIT" \
	--content S3Bucket=$(S3BUCKET),S3Key=$(LAYER_NAME).zip \
	--compatible-runtimes provided

sam-layer-package:
	@docker run -i $(EXTRA_DOCKER_ARGS) \
	-v $(PWD):/home/samcli/workdir \
	-v $(HOME)/.aws:/home/samcli/.aws \
	-w /home/samcli/workdir \
	-e AWS_DEFAULT_REGION=$(LAMBDA_REGION) \
	$(DOCKER_MIRROR)pahud/aws-sam-cli:latest sam package --template-file sam-layer.yaml --s3-bucket $(S3BUCKET) --output-template-file sam-layer-packaged.yaml
	@echo "[OK] Now type 'make sam-layer-deploy' to deploy your Lambda layer with SAM"


.PHONY: sam-layer-publish
sam-layer-publish:
	@docker run -i $(EXTRA_DOCKER_ARGS) \
	-v $(PWD):/home/samcli/workdir \
	-v $(HOME)/.aws:/home/samcli/.aws \
	-w /home/samcli/workdir \
	-e AWS_DEFAULT_REGION=$(LAMBDA_REGION) \
	$(DOCKER_MIRROR)pahud/aws-sam-cli:latest sam publish --region $(LAMBDA_REGION) --template sam-layer-packaged.yaml \
	--semantic-version $(shell cat VERSION)
	@echo "=> version $(shell cat VERSION) published to $(LAMBDA_REGION)"

sam-layer-deploy:
	@docker run -i \
	-v $(PWD):/home/samcli/workdir \
	-v $(HOME)/.aws:/home/samcli/.aws \
	-w /home/samcli/workdir \
	-e AWS_DEFAULT_REGION=$(LAMBDA_REGION) \
	$(DOCKER_MIRROR)pahud/aws-sam-cli:latest sam deploy --template-file ./sam-layer-packaged.yaml --stack-name "$(LAYER_NAME)-stack"
	# print the cloudformation stack outputs
	aws --region $(LAMBDA_REGION) cloudformation describe-stacks --stack-name "$(LAYER_NAME)-stack" --query 'Stacks[0].Outputs'
	@echo "[OK] Layer version deployed."

sam-layer-destroy:
	# destroy the layer stack	
	aws --region $(LAMBDA_REGION) cloudformation delete-stack --stack-name "$(LAYER_NAME)-stack"
	@echo "[OK] Layer version destroyed."
	
	
func-zip:
	rm -rf ./lambda-bundle; mkdir ./lambda-bundle
	chmod +x main.sh
	cp main.sh bootstrap ./lambda-bundle;
	cp Makefile ./lambda-bundle/Makefile;
	cd ./lambda-bundle && \
	zip -r ../func-bundle.zip *; ls -alh ../func-bundle.zip
	
create-func: func-zip
	@aws --profile=$(AWS_PROFILE) --region $(LAMBDA_REGION) lambda create-function \
	--function-name $(LAMBDA_FUNC_NAME) \
	--description $(LAMBDA_FUNC_DESC) \
	--runtime provided \
	--role  $(LAMBDA_ROLE_ARN) \
	--timeout 30 \
	--memory-size 512 \
	--layers $(LAMBDA_LAYERS) \
	--handler main \
	--zip-file fileb://func-bundle.zip 

update-func: func-zip
	@aws --profile=$(AWS_PROFILE) --region $(LAMBDA_REGION) lambda update-function-code \
	--function-name $(LAMBDA_FUNC_NAME) \
	--zip-file fileb://func-bundle.zip
	
func-all: func-zip update-func
layer-all: build layer-upload layer-publish


invoke:
	@aws --profile=$(AWS_PROFILE) --region $(LAMBDA_REGION) lambda invoke --function-name $(LAMBDA_FUNC_NAME)  \
	--payload '$(PAYLOAD)' lambda.output --log-type Tail | jq -r .LogResult | base64 -D	
	
add-layer-version-permission:
	@aws --profile=$(AWS_PROFILE) --region $(LAMBDA_REGION) lambda add-layer-version-permission \
	--layer-name $(LAYER_NAME) \
	--version-number $(LAYER_VER) \
	--statement-id public-all \
	--action lambda:GetLayerVersion \
	--principal '*'
	
	
.PHONY: publish-new-version-to-sar
publish-new-version-to-sar:
	@LAMBDA_REGION=us-east-1 make clean build sam-layer-package sam-layer-publish

.PHONY: publish-new-version-to-sar-cn
publish-new-version-to-sar-cn:
	@LAMBDA_REGION=cn-north-1 make clean build sam-layer-package sam-layer-publish

all: build layer-upload layer-publish
	
clean:
	rm -rf layer layer.zip func-bundle.zip lambda.output VERSION 
	

delete-func:
	@aws --profile=$(AWS_PROFILE) --region $(LAMBDA_REGION) lambda delete-function --function-name $(LAMBDA_FUNC_NAME)
	
clean-all: clean
	@aws --profile=$(AWS_PROFILE) --region $(LAMBDA_REGION) lambda delete-function --function-name $(LAMBDA_FUNC_NAME)
	
	
