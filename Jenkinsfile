pipeline {
    agent {
        label 'DevServer'
    }

    parameters {
        string(name: 'LASTNAME', defaultValue: 'Amara')
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
                sh 'mvn clean package'
                echo "Hello $NAME ${params.LASTNAME}"
            }
        }

        stage('Test') {
            parallel {

                stage('TestA') {
                    steps {
                        echo 'This is testA'
                    }
                }

                stage('TestB') {
                    steps {
                        echo 'This is testB'
                    }
                }
            }
        }
    }

    post {
        success {
            archiveArtifacts artifacts: '**/target/*.war'
        }
    }
}