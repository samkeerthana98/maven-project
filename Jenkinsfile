pipeline {
    agent {
        label 'DevServer'
    }

    tools {
        maven 'mymaven'
    }

    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }
    }

    post {
        success {
            archiveArtifacts artifacts: '**/target/*.war'
        }
    }
}