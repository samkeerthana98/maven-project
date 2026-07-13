stages {

    stage('Build') {
        steps {
            sh 'mvn clean package -DskipTests=true'
        }
    }

    stage('Test') {
        parallel {

            stage('TestA') {
                agent {
                    label 'DevServer'
                }
                steps {
                    echo 'Running TestA'
                    sh 'mvn test'
                }
            }

            stage('TestB') {
                agent {
                    label 'DevServer'
                }
                steps {
                    echo 'Running TestB'
                    sh 'mvn test'
                }
            }
        }
    }

    stage('Stash') {
        steps {
            dir('webapp/target') {
                stash name: 'maven-build', includes: '*.war'
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
                jar -xvf *.war
            '''
        }
    }
}