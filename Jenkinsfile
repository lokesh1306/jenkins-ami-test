pipeline {
    agent any

    environment {
        GITHUB_CREDENTIALS_ID = 'github'
        GITHUB_REPO_OWNER = 'cyse7125-su24-team15'
        GITHUB_REPO_NAME = 'ami-jenkins'
        GITHUB_API_URL = 'https://api.github.com/repos'
    }

    stages {
        stage('Intial') {
                        steps {
                script {
                    withCredentials([usernamePassword(credentialsId: env.GITHUB_CREDENTIALS_ID, usernameVariable: 'GITHUB_USERNAME', passwordVariable: 'GITHUB_TOKEN')]) {
                        def prCommitSHA = sh(script: "git ls-remote https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}.git refs/heads/${env.CHANGE_BRANCH} | cut -f1", returnStdout: true).trim()
                        echo "PR Commit SHA: ${prCommitSHA}"
                        env.PR_COMMIT_SHA = prCommitSHA
                    }
                }
            }
        }

        stage('Checkout') {
            steps {
                script {
                    echo 'Checking out the repository...'
                    try {
                        checkout scm
                    } catch (Exception e) {
                        echo "Checkout failed: ${e.message}"
                        currentBuild.result = 'FAILURE'
                        throw e
                    }
                }
            }
        }

        stage('Fetch Base Branch') {
            steps {
                script {
                    echo 'Fetching base branch from original repository...'
                    try {
                        withCredentials([usernamePassword(credentialsId: 'github', usernameVariable: 'GITHUB_USERNAME', passwordVariable: 'GITHUB_TOKEN')]) {
                            sh '''
                                git remote add upstream https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}.git || true
                                git fetch upstream main
                            '''
                        }
                    } catch (Exception e) {
                        echo "Fetch base branch failed: ${e.message}"
                        currentBuild.result = 'FAILURE'
                        throw e
                    }
                }
            }
        }

stage('Packer Validate') {
            steps {
                script {
                    echo 'Running Packer validate...'
                    try {
                        def result = sh(
                            script: 'packer validate ami.pkr.hcl',
                            returnStatus: true
                        )
                        if (result != 0) {
                            updateGitHubStatus('packer-validate', 'failure', 'Packer Validate check failed', env.ORIGINAL_COMMIT_SHA)
                            error('Packer validate check failed!')
                        }
                        // Adding debugging information before the success status update
                        echo "Packer validate succeeded. Updating GitHub status to success."
                        updateGitHubStatus('packer-validate', 'success', 'Packer Validate check passed', env.ORIGINAL_COMMIT_SHA)
                    } catch (Exception e) {
                        echo "Packer validate failed: ${e.message}"
                        currentBuild.result = 'FAILURE'
                        updateGitHubStatus('packer-validate', 'failure', 'Packer Validate check failed', env.ORIGINAL_COMMIT_SHA)
                        throw e
                    }
                }
            }
        }

        stage('Check Conventional Commits') {
            steps {
                script {
                    echo 'Checking Conventional Commits...'
                    try {
                        def commits = sh(script: 'git log --pretty=format:"%s" upstream/main..HEAD', returnStdout: true).trim().split('\n')
                        if (commits.size() == 1 && commits[0].isEmpty()) {
                            echo 'No new commits to check.'
                        } else {
                            echo "Commits to be checked: ${commits}"
                            def hasErrors = false
                            commits.each { commit ->
                                def result = sh(
                                    script: """
                                        echo "${commit}" | commitlint --config /tmp/commitlint-config/commitlint.config.js
                                    """,
                                    returnStatus: true
                                )
                                if (result != 0) {
                                    echo "Commit message failed: ${commit}"
                                    hasErrors = true
                                }
                            }
                            if (hasErrors) {
                                error('Conventional Commits check failed!')
                            }
                        }
                        updateGitHubStatus('conventional-commits', 'success', 'Conventional Commits check passed', env.ORIGINAL_COMMIT_SHA)
                    } catch (Exception e) {
                        echo "Conventional Commits check failed: ${e.message}"
                        currentBuild.result = 'FAILURE'
                        updateGitHubStatus('conventional-commits', 'failure', 'Conventional Commits check failed', env.ORIGINAL_COMMIT_SHA)
                        throw e
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                echo 'Cleaning up...'
                deleteDir()
            }
        }
    }
}

void updateGitHubStatus(String context, String state, String description, String commitSHA) {
    withCredentials([usernamePassword(credentialsId: env.GITHUB_CREDENTIALS_ID, usernameVariable: 'GITHUB_USERNAME', passwordVariable: 'GITHUB_TOKEN')]) {
        echo "Updating GitHub status: context=${context}, state=${state}, description=${description}, commit=${commitSHA}"
        def payload = """
            {
                "state": "${state}",
                "target_url": "${env.BUILD_URL}",
                "description": "${description}",
                "context": "${context}"
            }
        """
        echo "Payload: ${payload}"
        def response = sh(script: """
            curl -H "Authorization: token ${GITHUB_TOKEN}" \
                 -H "Content-Type: application/json" \
                 -X POST \
                 -d '${payload}' \
                 ${env.GITHUB_API_URL}/${env.GITHUB_REPO_OWNER}/${env.GITHUB_REPO_NAME}/statuses/${commitSHA}
        """, returnStdout: true).trim()
        echo "GitHub API response: ${response}"
        
        if (response.contains("error")) {
            error("GitHub status update failed: ${response}")
        } else {
            echo "GitHub status update successful: ${response}"
        }
    }
}