pipeline {
    agent {
        label 'DevServer'
    }

    parameters {
        choice(
            name: 'select_environment',
            choices: ['dev', 'prod'],
            description: 'Select deployment environment'
        )
    }

    environment {
        NAME = "samkeerthana"
    }

    tools {
        maven 'mymaven'
    }

    stages {

        stage('Build') {
            steps {
                sh 'mvn clean package -DskipTests=true'
                // Stash the artifact right after build so it's available downstream
                dir('webapp/target') {
                    stash name: 'maven-build', includes: '*.war'
                }
            }
        }

        stage('Test') {
            parallel {

                stage('TestA') {
                    agent {
                        label 'DevServer'
                    }
                    steps {
                        echo 'This is testA'
                        sh 'mvn test'
                    }
                }

                stage('TestB') {
                    agent {
                        label 'DevServer'
                    }
                    steps {
                        echo 'This is testB'
                        sh 'mvn test'
                    }
                }

            }
        }

        stage('Deploy Dev') {
            when {
                beforeAgent true
                expression {
                    params.select_environment == 'dev'
                }
            }

            agent {
                label 'DevServer'
            }

            steps {
                // Restore artifact into the Jenkins workspace
                unstash 'maven-build'
                sh '''
                    echo "Current Workspace:"
                    pwd

                    echo "Searching for WAR file..."
                    find . -name "*.war"

                    WAR=$(find . -name "*.war" | head -1)

                    if [ -z "$WAR" ]; then
                        echo "ERROR: No WAR file found!"
                        exit 1
                    fi

                    echo "WAR file found: $WAR"

                    sudo cp "$WAR" /var/www/html/

                    cd /var/www/html

                    sudo jar -xvf "$(basename "$WAR")"
                '''
            }
        }

    }

    post {
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed!"
        }
    }
}