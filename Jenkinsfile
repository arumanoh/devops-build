pipeline {
    agent any

    environment {
        DOCKER_USER = 'arumanoh'
        APP_HOST    = '172.31.32.104'
    }

    stages {
        stage('Select repo') {
            steps {
                script {
                    env.REPO  = (env.BRANCH_NAME == 'master') ? 'prod' : 'dev'
                    env.IMAGE = "${DOCKER_USER}/${env.REPO}"
                }
                echo "Branch: ${env.BRANCH_NAME} -> image ${env.IMAGE}"
            }
        }

        stage('Build') {
            steps {
                sh "docker build -t ${IMAGE}:${BUILD_NUMBER} -t ${IMAGE}:latest ."
            }
        }

        stage('Push') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                                  usernameVariable: 'DH_USER',
                                                  passwordVariable: 'DH_PASS')]) {
                    sh 'echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin'
                    sh "docker push ${IMAGE}:${BUILD_NUMBER}"
                    sh "docker push ${IMAGE}:latest"
                    sh 'docker logout'
                }
            }
        }

        stage('Deploy') {
            steps {
                sshagent(['app-server-ssh']) {
                    sh """
                        scp -o StrictHostKeyChecking=accept-new docker-compose.yml ubuntu@${APP_HOST}:~/docker-compose.yml
                        ssh -o StrictHostKeyChecking=accept-new ubuntu@${APP_HOST} \
                          'export IMAGE_NAME=${IMAGE} IMAGE_TAG=${BUILD_NUMBER}; docker compose pull && docker compose up -d --no-build && docker image prune -f'
                    """
                }
            }
        }
    }
}
