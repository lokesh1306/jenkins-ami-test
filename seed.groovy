pipelineJob('Multi-Platform-Container-Image') {
    definition {
        cps {
            script("""
                pipeline {
                    agent any
                    triggers {
                      githubPush()
                    } 
                    environment {
                        DOCKER_CREDENTIALS_ID = 'dockerhub'
                        DOCKERHUB_REPO = 'chlokesh1306/lokesh'
                        GITHUB_CREDENTIALS_ID = 'github'
                    }
                    stages {
                        stage('Checkout') {
                            steps {
                                git branch: 'main', url: 'https://github.com/cyse7125-su24-team15/static-site', credentialsId: env.GITHUB_CREDENTIALS_ID
                            }
                        }
                        stage('Build and Publish') {
                            steps {
                                script {
                                    docker.withRegistry('', env.DOCKER_CREDENTIALS_ID) {
                                        sh 'docker run --rm --privileged multiarch/qemu-user-static --reset -p yes'
                                        sh 'docker buildx create --name csye7125 --driver docker-container --use || docker buildx use csye7125'
                                        sh 'docker buildx inspect csye7125 --bootstrap'
                                        sh 'docker buildx build --platform linux/amd64,linux/arm64 -t "\${DOCKERHUB_REPO}:latest" --push .'
                                    }
                                }
                            }
                        }
                    }
                    post {
                        always {
                            deleteDir()
                        }
                    }
                }
            """.stripIndent())
            sandbox(false)
        }
    }
    triggers {
        githubPush()
    }
}

pipelineJob('AMI-Packer-Validate') {
    definition {
        cps {
            script('''
                pipeline {
                    agent any

                    environment {
                        GITHUB_CREDENTIALS_ID = 'github'
                        GITHUB_REPO_OWNER = 'cyse7125-su24-team15'  
                        GITHUB_REPO_NAME = 'ami-jenkins'      
                        GITHUB_API_URL = 'https://api.github.com/repos'
                        GIT_COMMIT = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                    }

                    stages {
                        stage('Checkout') {
                            steps {
                                checkout scm
                            }
                        }

                        stage('Packer Validate') {
                            steps {
                                script {
                                    def result = sh(
                                        script: 'packer validate ami.pkr.hck',
                                        returnStatus: true
                                    )
                                    if (result != 0) {
                                        error('Packer validate check failed!')
                                    }
                                }
                            }
                        }

                        stage('Check Conventional Commits') {
                            steps {
                                script {
                                    def result = sh(
                                        script: 'git log --pretty=format:"%s" origin/main..HEAD | conventional-changelog-lint -p angular',
                                        returnStatus: true
                                    )
                                    if (result != 0) {
                                        error('Conventional Commits check failed!')
                                    }
                                }
                            }
                        }
                    }

                    post {
                        always {
                            script {
                                def packerStatus = currentBuild.currentResult == 'SUCCESS' ? 'success' : 'failure'
                                def commitsStatus = currentBuild.currentResult == 'SUCCESS' ? 'success' : 'failure'
                                withCredentials([string(credentialsId: env.GITHUB_CREDENTIALS_ID, variable: 'GITHUB_TOKEN')]) {
                                    sh """
                                        curl -H "Authorization: token ${GITHUB_TOKEN}" \
                                             -H "Content-Type: application/json" \
                                             -X POST \
                                             -d '{
                                                 "state": "${packerStatus}",
                                                 "target_url": "${env.BUILD_URL}",
                                                 "description": "Packer Validate check",
                                                 "context": "packer-validate"
                                             }' \
                                             ${env.GITHUB_API_URL}/${env.GITHUB_REPO_OWNER}/${env.GITHUB_REPO_NAME}/statuses/${env.GIT_COMMIT}
                                    """
                                    sh """
                                        curl -H "Authorization: token ${GITHUB_TOKEN}" \
                                             -H "Content-Type: application/json" \
                                             -X POST \
                                             -d '{
                                                 "state": "${commitsStatus}",
                                                 "target_url": "${env.BUILD_URL}",
                                                 "description": "Conventional Commits check",
                                                 "context": "conventional-commits"
                                             }' \
                                             ${env.GITHUB_API_URL}/${env.GITHUB_REPO_OWNER}/${env.GITHUB_REPO_NAME}/statuses/${env.GIT_COMMIT}
                                    """
                                }
                            }
                            deleteDir()
                        }
                    }
                }
            '''.stripIndent())
            sandbox(false)
        }
    }
    triggers {
        githubPush()
    }
}
