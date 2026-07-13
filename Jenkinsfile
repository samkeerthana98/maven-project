pipeline {
    agent {
        label 'DevServer'
    }
    parameters {
        string defaultValue: 'sam', name: 'LASTNAME'
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

    post {
        success {
            archiveArtifacts artifacts: '**/target/*.war'
        }
    }
}