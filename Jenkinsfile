// Jenkinsfile — deploy-to-kubernetes (CS411)
//
// Build + push the image (ttl.sh), then authenticate to the cluster API
// with a ServiceAccount bearer token and apply the Pod (+ Service) manifest.
// The image is rebuilt/pushed every run because ttl.sh tags are short-lived.

pipeline {
    agent any

    environment {
        IMAGE      = 'ttl.sh/maydamv-cs411-devops:2h'
        K8S_API    = 'https://kubernetes:6443'
        K8S_TOKEN_ID = 'k8s-token'
        // shared kubectl connection flags (token added per-call from creds)
        KUBE_ARGS  = '--server=https://kubernetes:6443 --insecure-skip-tls-verify=true'
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

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([string(credentialsId: env.K8S_TOKEN_ID, variable: 'K8S_TOKEN')]) {
                    sh '''
                        kubectl ${KUBE_ARGS} --token="$K8S_TOKEN" apply -f k8s/myapp-pod.yaml
                        kubectl ${KUBE_ARGS} --token="$K8S_TOKEN" apply -f k8s/myapp-service.yaml
                    '''
                }
            }
        }

        stage('Wait for Ready') {
            steps {
                withCredentials([string(credentialsId: env.K8S_TOKEN_ID, variable: 'K8S_TOKEN')]) {
                    sh '''
                        kubectl ${KUBE_ARGS} --token="$K8S_TOKEN" wait --for=condition=Ready pod/myapp --timeout=90s
                        kubectl ${KUBE_ARGS} --token="$K8S_TOKEN" get pod myapp -o wide
                    '''
                }
            }
        }
    }

    post {
        success { echo "Pod myapp is Running and serving on :4444" }
        failure {
            withCredentials([string(credentialsId: env.K8S_TOKEN_ID, variable: 'K8S_TOKEN')]) {
                sh '''
                    kubectl ${KUBE_ARGS} --token="$K8S_TOKEN" describe pod myapp || true
                '''
            }
        }
    }
}
