# Teste Devops - Relatório
Carlos Eduardo Cichon Henriques  

---

[TOC]
## Ferramentas utilizadas
- [Circleci](https://circleci.com/)
- [Terraform](https://www.terraform.io/)
- [AWS](https://aws.amazon.com/pt/?nc2=h_lg)
- [Docker](https://www.docker.com/)
- [Github](https://github.com/carloscichon/carlos-devops-teste)

## Instalações
### Circlecli e Docker
Não é necessário instalar nada para usar o circleci em si, mas a interface de linha de comando do pode ser útil para validar o arquivo de configuração sem ter de fazer diversos commits. Ela pode ser instalada com:
```
sudo snap install docker circleci
sudo snap connect circleci:docker docker
```
### Terraform
```
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```
### AWS
Também não é necessário instalar nada para utilizar a AWS, porém assim como com o circleci, a AWS CLI pode ser útil em alguns momentos:
```
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

## Passos realizados

### Fork do Projeto
Meu primeiro passo foi realizar um fork do projeto base do app em nodejs para o meu próprio Github. Disponível [aqui](https://github.com/carloscichon/carlos-devops-teste)

### Configuração do projeto no CircleCi
Depois eu criei uma conta no CircleCi e fiz a integração com o meu Github. Dessa forma, todos os projetos dele podem virar pipelines no CircleCi.
Em seguida, adicionei ao meu projeto do Github um arquivo básico de configuração `.circleci/config.yml`.
Esse arquivo será responsável por organizar as estruturas do meu pipeline. Num primeiro momento eu configurei apenas com os passos de checkout e de teste.

### Criação do Dockerfile
Para realizar o deploy posteriormente na AWS é necessário criar uma imagem docker para a aplicação. Ele ficou dessa forma:
```
FROM node:18.16.0
RUN mkdir ~/app
WORKDIR ~/app
COPY app/ .
RUN npm install
EXPOSE 3000
CMD ["npm", "start"]
```

### Criação e configuração da Conta na AWS
Para realizar o deploy também foi necessário uma conta na AWS para criar os recursos. A conta pode ser criada [aqui](https://portal.aws.amazon.com/billing/signup). 
Além disso, para automatizar as criações de recursos via Terraform, foi necessário criar Chaves de Acesso.

### Configuração do Terraform
No arquivo `terraform_config/main.tf` estão descritos todas os recursos que devem ser criados na AWS e suas configurações. Sua versão final pode ser encontrada [aqui](https://github.com/carloscichon/carlos-devops-teste/blob/master/terraform_config/main.tf). 
Foram criados os seguintes recursos:
- ECR para armazenar as imagens do app
- ECS para e FARGATE o serviço que roda as instãncias da aplicação.
- VPC e Subnets para expor o serviço para a internet.
- Loadbalancer para equilibrar a carga e acessar o serviço.

> Também é necessário inserir as informações de autenticação da AWS do arquivo do terraform.

Com tudo descrito no `main.tf`, os seguintes comandos do Terraform devem ser executados:
```
terraform init
terraform plan
terraform apply
```

### Finalização da configuração do CircleCi
Primeiramente, é necessário configurar algumas variáveis de ambiente no projeto do CircleCi. Dessa forma:

![Captura de tela de 2023-11-11 00-32-47](https://hackmd.io/_uploads/r1_bI_2ma.png)

Com os recursos criados na AWS, e variáveis criadas é possível agora terminar a configuração do CircleCi no projeto. Em sua última versão, ele ficou desta maneira:
```
version: 2.1
orbs:
  node: circleci/node@5.1.0
  aws-ecr: circleci/aws-ecr@8.1.2
  aws-ecs: circleci/aws-ecs@3.2.0
  aws-cli: circleci/aws-cli@4.1.1

jobs:
  node-app:
    executor:
      name: node/default
      tag: 14.15.1
    steps:
      - checkout
      - run:
          working_directory: ~/project/app/
          command: npm test
          name: Test
workflows:
  devops-teste:
    jobs:
    - node-app
    - aws-ecr/build-and-push-image:
        repo: "${AWS_RESOURCE_NAME_PREFIX}"
        tag: "latest"
        requires:
          - node-app
    - aws-ecs/deploy-service-update:
        requires:
          - aws-ecr/build-and-push-image # only run this job once aws-ecr/build-and-push-image has completed
        family: "node-app-task"
        cluster: "node-app-cluster"
        service-name: "node-app-service"
        force-new-deployment: true
        container-image-name-updates: "container=node-app-task,tag=latest"
```

Nele o job ***node-app*** é o responsável por realizar o checkout do código do Git e também rodar o teste com `npm run test`.
Já o job ***aws-ecr/build-and-push-image*** é um job pronto do orb do ECR responsável pelo build e por enviar a imagem recém feita ao ECR da AWS.
Por fim, o ***aws-ecs/deploy-service-update*** é o job responsável por atualizar o serviço no ECS e realizar um novo deploy com a nova imagem recém construída.

### Resultados
Como resultados, temos a construção de um deploy totalmente automatizado. Um commit no Github ativará o gatilho do pipeline no CicleCi. Então o código passará por um checkout, teste, build (cuja imagem será enviada ao ECR) e deploy (que atualiza o serviço no ECS com a imagem recém construída e lança novas réplicas).

A aplicação pode ser conferida em:
http://load-balancer-dev-2064627.us-east-2.elb.amazonaws.com/
