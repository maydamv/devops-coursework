// Jenkinsfile — first-deployment-pipeline (CS411)
//
// Three stages: build the Go binary on the Jenkins node, copy it to the
// target machine over SSH, and start it there. Adjust the env block to
// match the playground (target host, SSH user, credential ID) once you
// see those values in Jenkins.

pipeline {
    agent any

    environment {
        APP_NAME       = 'main'
        APP_PORT       = '4444'
        TARGET_HOST    = 'target'          // TODO confirm hostname in iximiuz
        TARGET_USER    = 'root'            // TODO confirm SSH user in iximiuz
        TARGET_PATH    = '/usr/local/bin/main'
        SSH_CRED_ID    = 'target-ssh'      // TODO confirm credential ID in Jenkins
    }

    stages {

        stage('Build') {
            steps {
                sh 'go version'
                sh 'go build -o ${APP_NAME} main.go'
                sh 'ls -la ${APP_NAME}'
            }
        }

        stage('Ship') {
            steps {
                sshagent(credentials: [SSH_CRED_ID]) {
                    sh '''
                        scp -o StrictHostKeyChecking=no \
                            ${APP_NAME} ${TARGET_USER}@${TARGET_HOST}:${TARGET_PATH}
                        ssh -o StrictHostKeyChecking=no \
                            ${TARGET_USER}@${TARGET_HOST} "chmod +x ${TARGET_PATH}"
                    '''
                }
            }
        }

        stage('Run') {
            steps {
                sshagent(credentials: [SSH_CRED_ID]) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ${TARGET_USER}@${TARGET_HOST} "
                            pkill -f ${TARGET_PATH} || true
                            nohup ${TARGET_PATH} > /var/log/myapp.log 2>&1 &
                            sleep 1
                            curl -fsS http://localhost:${APP_PORT}/
                        "
                    '''
                }
            }
        }
    }

    post {
        success { echo "Deployed ${APP_NAME} to ${TARGET_HOST}:${APP_PORT}" }
        failure { echo "Build failed — check the stage logs above" }
    }
}
