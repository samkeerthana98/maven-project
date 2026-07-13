pipeline {
    agent {
        label 'DevServer'
    }

    parameters {
        choice choices: ['dev', 'prod'], name: 'select_environment'

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
               
            }
        }
        stage('Test') {
            parallel {
                stage('TestA') {
                    agent { label 'DevServer'}
                    steps {
                        echo 'This is testA'
                        sh "mvn test"
                    }
                }

                stage('TestB') {
                    agent { label 'DevServer'}
                    steps {
                        echo 'This is testB'
                        sh "mvn test"
                    }
                }
            }
        }
    }

    post {
        success {
            dir("webapp/target/")
            {
                stash name: "maven-build", includes: "*.war"
            }
        }
    }
    stage('deploy_dev') {
        when {expression {params.select_environment == 'dev'}}
        beforeAgent=true
        agent { label 'DevServer'}
        steps {
            dir("/var/www/html") 
            {
                unstash "maven-build"
            }
            sh """ 
            cd /var/www/html/
            jar -xvf webapp.war
            """
        }
    }
}