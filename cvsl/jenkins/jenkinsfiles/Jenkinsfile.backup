pipeline {
  agent any

  environment {
    XOA_URL = credentials('xoa_url')
    XOA_USER = credentials('xoa_user')
    XOA_PASSWORD = credentials('xoa_password')
    JENKINS_PUB_KEY = credentials('jenkins-pub-key')
    MINIO_ENDPOINT   = credentials('minio_endpoint')
    MINIO_ACCESS_KEY = credentials('minio_access_key')
    MINIO_SECRET_KEY = credentials('minio_secret_key')
  }
  
  parameters {
    choice(
      name: 'CREATE_OR_DESTROY',
      choices: ['Create', 'Destroy'],
      description: 'Would you like to create or destroy the Kubernetes cluster?'
    )
    // booleanParam(
    //   name: 'DEBUG',
    //   defaultValue: false,
    //   description: 'Se ativado, exporta os valores das credenciais como artefatos para depuração'
    // )
  }

  stages {

    // stage('Exportar credenciais para artefatos') {
    //   when {
    //     expression { return params.DEBUG }
    //   }
    //   steps {
    //     withCredentials([
    //       string(credentialsId: 'xoa_user', variable: 'REAL_XOA_USER'),
    //       string(credentialsId: 'xoa_password', variable: 'REAL_XOA_PASSWORD'),
    //       string(credentialsId: 'aws_access_key_id', variable: 'REAL_AWS_ACCESS_KEY_ID'),
    //       string(credentialsId: 'aws_secret_access_key', variable: 'REAL_AWS_SECRET_ACCESS_KEY'),
    //       string(credentialsId: 'jenkins-pub-key', variable: 'REAL_JENKINS_PUB_KEY'),
    //       sshUserPrivateKey(credentialsId: 'jenkins-priv-key', keyFileVariable: 'JENKINS_PRIV_KEY'),
    //     ]) {
    //       sh '''
    //         echo "$REAL_XOA_USER" > xoa_user.txt
    //         echo "$REAL_XOA_PASSWORD" > xoa_password.txt
    //         echo "$REAL_AWS_ACCESS_KEY_ID" > aws_access_key_id.txt
    //         echo "$REAL_AWS_SECRET_ACCESS_KEY" > aws_secret_access_key.txt
    //         echo "$REAL_JENKINS_PUB_KEY" > jenkins_pub_key.txt
    //         cat "$SSH_PRIVATE_KEY" > jenkins_priv_key.txt
    //       '''
    //     }

    //     archiveArtifacts artifacts: 'xoa_user.txt', onlyIfSuccessful: true
    //     archiveArtifacts artifacts: 'xoa_password.txt', onlyIfSuccessful: true
    //     archiveArtifacts artifacts: 'aws_access_key_id.txt', onlyIfSuccessful: true
    //     archiveArtifacts artifacts: 'aws_secret_access_key.txt', onlyIfSuccessful: true
    //     archiveArtifacts artifacts: 'jenkins_pub_key.txt', onlyIfSuccessful: true
    //     archiveArtifacts artifacts: 'jenkins_priv_key.txt', onlyIfSuccessful: true
    //   }
    // }
    
    stage('ssh keys') {
      agent {
        docker {
          image 'alpine'
        }
      }
      steps {
        dir('terraform') {
          withCredentials([
            sshUserPrivateKey(credentialsId: 'jenkins-priv-key', keyFileVariable: 'JENKINS_PRIV_KEY'),
            ]) {
            sh '''
              cat "$JENKINS_PRIV_KEY" > id_ed25519
              echo "$JENKINS_PUB_KEY" > id_ed25519.pub
            '''
            }
        }
      }
    }

    stage('endpoints') {
      steps {
        script {
          def minioIp = sh(script: "getent hosts minio | awk '{ print \$1 }'", returnStdout: true).trim()
          env.MINIO_URL = minioIp
          def xoaIp = sh(script: "getent hosts xen-orchestra | awk '{ print \$1 }'", returnStdout: true).trim()
          env.XOA_IP = xoaIp
        }
      }
    }

    stage('backend.hcl') {
        agent {
          docker {
              image 'hairyhenderson/gomplate:alpine'
              args "--entrypoint= -v ${PWD}:/work -w /work --env MINIO_ENDPOINT=${MINIO_ENDPOINT} --env MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY} --env MINIO_SECRET_KEY=${MINIO_SECRET_KEY}"
          }
        }
        // environment {
        //   MINIO_ENDPOINT   = credentials('minio_endpoint')
        //   MINIO_ACCESS_KEY = credentials('minio_access_key')
        //   MINIO_SECRET_KEY = credentials('minio_secret_key')
        // }
        steps {
          dir('terraform') {
            sh '''
            /bin/gomplate -f backend.hcl.tpl -o backend.hcl -V
            '''
        }
    }
    }

    stage('terraform.tfvars') {
        agent {
          docker {
              image 'hairyhenderson/gomplate:alpine'
              args "--entrypoint= -v ${PWD}:/work -w /work --env XOA_URL=${XOA_URL} --env XOA_USER=${XOA_USER} --env XOA_PASSWORD=${XOA_PASSWORD}"
          }
        }
        environment {
          MINIO_ENDPOINT   = credentials('minio_endpoint')
          MINIO_ACCESS_KEY = credentials('minio_access_key')
          MINIO_SECRET_KEY = credentials('minio_secret_key')
        }
        steps {
          dir('terraform') {
            sh '''
            /bin/gomplate -f terraform.tfvars.tpl -o terraform.tfvars -V
            '''

        }
    }
    }

    stage('terraform init') {
      agent {
        docker {
          image 'hashicorp/terraform:1.11.4'
          args "--entrypoint= --add-host minio:${env.MINIO_URL} --add-host xen-orchestra:${env.XOA_IP}"
        }
      }
      steps {
        dir('terraform'){
        sh '''
          #terraform init -no-color -migrate-state -backend-config=backend.hcl
          terraform init -no-color
        '''
        }
      }
    }
  
    stage('terraform plan') {
      agent {
        docker {
          image 'hashicorp/terraform:1.11.4'
          args "--entrypoint= --add-host minio:${env.MINIO_URL} --add-host xen-orchestra:${env.XOA_IP}"
        }
      }
      steps {
        dir('terraform'){
              sh '''
                terraform plan -no-color
              '''
        }
      }
      when {
        expression {
          params.CREATE_OR_DESTROY == "Create"
        }
      }
    }

    stage('terraform apply') {
      agent {
        docker {
          image 'hashicorp/terraform:1.11.4'
          args "--entrypoint= --add-host minio:${env.MINIO_URL} --add-host xen-orchestra:${env.XOA_IP}"
        }
      }
      steps {
        dir('terraform'){
        sh '''
          terraform apply -no-color -auto-approve
        '''
        }
      }
      when {
        expression {
          params.CREATE_OR_DESTROY == "Create"
        }
      }
    }

    stage('kubespray') {
      agent {
        docker {
          image 'quay.io/kubespray/kubespray:v2.28.0'
          args '--entrypoint="" -u root'
        }
      }
      steps {
        dir('terraform') {
          sh '''
            export ANSIBLE_ROLES_PATH="$ANSIBLE_ROLES_PATH:/kubespray/roles"
            export ANSIBLE_HOST_KEY_CHECKING="False"

            ansible-playbook \
              --become \
              --inventory inventory.ini \
              --private-key id_ed25519 \
              /kubespray/cluster.yml
          '''
        }
      }
      when {
        expression {
          params.CREATE_OR_DESTROY == "Create"
        }
      }
    }

    stage('terraform destroy') {
      agent {
        docker {
          image 'hashicorp/terraform:1.11.4'
          args "--entrypoint= --add-host minio:${env.MINIO_URL} --add-host xen-orchestra:${env.XOA_IP}"
        }
      }
      steps {
        dir('terraform') {
          sh '''
            terraform apply -destroy -no-color -auto-approve
          '''
        }
      }
      when {
        expression {
          params.CREATE_OR_DESTROY == "Destroy"
        }
      }
    }


}
}

