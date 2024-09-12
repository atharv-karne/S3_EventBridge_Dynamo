pipeline
{
    agent any


    environment
    {
        TERRAFORM_CREDENTIALS_ID = 'AWS-Cred'
        AWS_REGION = 'ap-south-1'
        CSV_NAME = 'color_srgb.csv'
        BUCKET_NAME = 'csv-bucket-jenkins-unique-66'
        AWS_REGION = 'ap-south-1'

    }
    stages
    {
        stage('Terraform init')
        {
            withCredentials([aws(credentialsId: TERRAFORM_CREDENTIALS_ID, region: AWS_REGION)])
            {
                script
                {
                    sh 'terraform init'
                }
            }
        }
        stage('Terraform apply')
        {
            withCredentials([aws(credentialsId: TERRAFORM_CREDENTIALS_ID, region: AWS_REGION)])
            {
                script
                {
                    sh 'terraform plan'
                    sh 'terraform apply -auto-approve'
                }
            }

        }
        stage('Upload csv')
        {
            withCredentials([aws(credentialsId: TERRAFORM_CREDENTIALS_ID, region: AWS_REGION)])
            {
            script {
                sh 'aws --version'
                sh "aws s3 cp CSV_NAME s3://${BUCKET_NAME}/color_srgb.csv --region ${AWS_REGION}"
                }
 
            }

        }
    }

}