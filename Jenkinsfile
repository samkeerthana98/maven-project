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
                dir('/var/www/html') {
                    unstash 'maven-build'
                }

                sh '''
                    cd /var/www/html
                    jar -xvf webapp.war
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