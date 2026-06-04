// Jenkinsfile — deployment-to-cloud (CS411)
//
// Build the Go binary on the Jenkins node, ship it to a real AWS EC2
// instance over SSH, and run it under systemd (same shape as
// first-deployment-pipeline, different target host).
//
// EC2_IP and EC2_USER are build parameters so the public IP never gets
// committed and the AMI's login user can vary (ubuntu / ec2-user).
// The .pem private key lives in the 'ec2-ssh' Jenkins credential.

pipeline {
    agent any

    parameters {
        string(name: 'EC2_IP',   defaultValue: '',       description: 'Public IP of the EC2 instance')
        string(name: 'EC2_USER', defaultValue: 'ubuntu', description: 'SSH login user (ubuntu for Ubuntu AMI, ec2-user for Amazon Linux)')
    }

    environment {
        APP_NAME    = 'main'
        APP_PORT    = '4444'
        TARGET_PATH = '/usr/local/bin/main'
        SVC_NAME    = 'myapp'
        SSH_CRED_ID = 'ec2-ssh'
        SSH_OPTS    = '-o StrictHostKeyChecking=no'
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
                withCredentials([sshUserPrivateKey(credentialsId: env.SSH_CRED_ID, keyFileVariable: 'SSH_KEY')]) {
                    sh '''
                        scp ${SSH_OPTS} -i "$SSH_KEY" ${APP_NAME} ${EC2_USER}@${EC2_IP}:/tmp/main
                        scp ${SSH_OPTS} -i "$SSH_KEY" deploy/myapp.service ${EC2_USER}@${EC2_IP}:/tmp/myapp.service
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: env.SSH_CRED_ID, keyFileVariable: 'SSH_KEY')]) {
                    sh '''
                        ssh ${SSH_OPTS} -i "$SSH_KEY" ${EC2_USER}@${EC2_IP} '
                            set -e
                            id myapp >/dev/null 2>&1 || sudo useradd --system --no-create-home --shell /usr/sbin/nologin myapp
                            sudo install -m 0755 /tmp/main /usr/local/bin/main
                            sudo install -m 0644 /tmp/myapp.service /etc/systemd/system/myapp.service
                            sudo systemctl daemon-reload
                            sudo systemctl enable myapp
                            sudo systemctl restart myapp
                        '
                    '''
                }
            }
        }

        stage('Health check') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: env.SSH_CRED_ID, keyFileVariable: 'SSH_KEY')]) {
                    sh '''
                        ssh ${SSH_OPTS} -i "$SSH_KEY" ${EC2_USER}@${EC2_IP} '
                            for i in $(seq 1 10); do
                                if curl -fsS http://localhost:'${APP_PORT}'/ | grep -q "\\"Name\\":\\"Hello\\""; then
                                    echo "App is serving traffic on '${APP_PORT}' (locally on the instance)"
                                    exit 0
                                fi
                                echo "waiting for app... ($i/10)"
                                sleep 1
                            done
                            echo "App did not become healthy in time"
                            sudo journalctl -u myapp --no-pager -n 30
                            exit 1
                        '
                    '''
                }
            }
        }
    }

    post {
        success { echo "Deployed ${SVC_NAME} to EC2 ${EC2_IP}:${APP_PORT} — now paste that IP into iximiuz" }
        failure { echo "Build failed — check the stage logs above" }
    }
}
