// Jenkinsfile — docker-build-deploy (CS411)
//
// Build a Docker image from the repo on the Jenkins node, push it to the
// anonymous ttl.sh registry, then on the docker VM pull the image and run
// a container exposing :4444. A health check gates the build on the
// container actually serving traffic.

pipeline {
    agent any

    environment {
        IMAGE       = 'ttl.sh/maydamv-cs411-devops:2h'
        APP_PORT    = '4444'
        DOCKER_VM   = 'docker'
        SSH_CRED_ID = 'target-ssh'
        SSH_OPTS    = '-o StrictHostKeyChecking=no'
    }

    stages {

        stage('Build image') {
            steps {
                sh 'docker build -t ${IMAGE} .'
            }
        }

        stage('Push') {
            steps {
                sh 'docker push ${IMAGE}'
            }
        }

        stage('Deploy on docker VM') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: env.SSH_CRED_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                    sh '''
                        ssh ${SSH_OPTS} -i "$SSH_KEY" "$SSH_USER"@${DOCKER_VM} '
                            docker pull '${IMAGE}'
                            docker rm -f myapp 2>/dev/null || true
                            docker run -d --name myapp -p '${APP_PORT}':'${APP_PORT}' '${IMAGE}'
                        '
                    '''
                }
            }
        }

        stage('Health check') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: env.SSH_CRED_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                    sh '''
                        ssh ${SSH_OPTS} -i "$SSH_KEY" "$SSH_USER"@${DOCKER_VM} '
                            for i in $(seq 1 10); do
                                if curl -fsS http://localhost:'${APP_PORT}'/ | grep -q "\\"Name\\":\\"Hello\\""; then
                                    echo "Container is serving traffic on port '${APP_PORT}'"
                                    exit 0
                                fi
                                echo "waiting for container... ($i/10)"
                                sleep 1
                            done
                            echo "Container did not become healthy in time"
                            docker logs myapp || true
                            exit 1
                        '
                    '''
                }
            }
        }
    }

    post {
        success { echo "Deployed ${IMAGE} to ${DOCKER_VM}:${APP_PORT}" }
        failure { echo "Build failed — check the stage logs above" }
    }
}
