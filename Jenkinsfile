// Jenkinsfile — first-deployment-pipeline (CS411)
//
// Build the Go binary on the Jenkins node, ship it to the target machine
// over SSH, install it as a systemd service (so it survives the SSH session
// that started it), and gate the build on a real health check.
//
// Uses withCredentials + sshUserPrivateKey (the SSH Agent plugin is not
// installed on this Jenkins), which hands us a temporary private-key file.

pipeline {
    agent any

    environment {
        APP_NAME    = 'main'
        APP_PORT    = '4444'
        TARGET_HOST = 'target'
        TARGET_PATH = '/usr/local/bin/main'
        SVC_NAME    = 'myapp'
        SSH_CRED_ID = 'target-ssh'
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
                withCredentials([sshUserPrivateKey(credentialsId: env.SSH_CRED_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                    sh '''
                        scp ${SSH_OPTS} -i "$SSH_KEY" main "$SSH_USER"@${TARGET_HOST}:/tmp/main
                        scp ${SSH_OPTS} -i "$SSH_KEY" deploy/myapp.service "$SSH_USER"@${TARGET_HOST}:/tmp/myapp.service
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: env.SSH_CRED_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                    sh '''
                        ssh ${SSH_OPTS} -i "$SSH_KEY" "$SSH_USER"@${TARGET_HOST} '
                            set -e
                            # dedicated non-root service account (idempotent)
                            id myapp >/dev/null 2>&1 || sudo useradd --system --no-create-home --shell /usr/sbin/nologin myapp

                            # install the binary atomically (install replaces in one move,
                            # so a re-run never trips over a half-copied or busy file)
                            sudo install -m 0755 /tmp/main /usr/local/bin/main

                            # install/refresh the unit and (re)start through systemd
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
                withCredentials([sshUserPrivateKey(credentialsId: env.SSH_CRED_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                    sh '''
                        ssh ${SSH_OPTS} -i "$SSH_KEY" "$SSH_USER"@${TARGET_HOST} '
                            for i in $(seq 1 10); do
                                if curl -fsS http://localhost:'${APP_PORT}'/ | grep -q "\\"Name\\":\\"Hello\\""; then
                                    echo "App is serving traffic on port '${APP_PORT}'"
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
        success { echo "Deployed ${SVC_NAME} to ${TARGET_HOST}:${APP_PORT} via systemd" }
        failure { echo "Build failed — check the stage logs above" }
    }
}
