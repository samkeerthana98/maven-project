pipeline {
    agent {
        label 'DevServer'
    }
    parameters {
        string defaultValue: 'Amara', name: 'LASTNAME'
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
    }
    stage('test')
    {
        parallel {
            stage('testA') {
                steps {
                    echo 'This is testA'
                }
            }
            stage('testB') {
                steps {
                    echo 'This is testB'
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