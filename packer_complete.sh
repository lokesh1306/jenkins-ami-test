#!/bin/bash

# Configure Nginx
sudo rm /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/

# Add service
sudo sh -c "echo '[Unit]
Description=Run Certbot Initial Script at Boot
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/certbot_initial.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target' >> /lib/systemd/system/certbot.service"
sudo systemctl daemon-reload
sudo systemctl enable certbot

# Schedule Certbot renewal
sudo crontab -l > /tmp/cron
echo '0 3 * * * /usr/local/bin/certbot_renewal.sh' >> /tmp/cron
sudo crontab /tmp/cron

# Wait for Jenkins
while [ "$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)" != "403" ]; do
    echo "Waiting"
    sleep 5
done

# Jenkins CLI
sudo wget http://localhost:8080/jnlpJars/jenkins-cli.jar -O /tmp/jenkins-cli.jar

# Install Jenkins plugins
sudo java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ -auth admin:$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword) install-plugin git github github-api credentials job-dsl docker-workflow conventional-commits github-branch-source

# Install Docker
sudo apt-get install docker.io -y
sudo apt-get install docker-buildx -y
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Moving required files
sudo mkdir -p /var/lib/jenkins/workspace/seed-job
sudo mkdir -p /var/lib/jenkins/init.groovy.d
sudo mv /home/ubuntu/jenkins_nginx_initial.conf /etc/nginx/sites-available/jenkins
sudo mv /home/ubuntu/certbot_initial.sh /usr/local/bin/certbot_initial.sh
sudo mv /home/ubuntu/certbot_renewal.sh /usr/local/bin/certbot_renewal.sh
sudo mv /home/ubuntu/01-credentials.groovy /var/lib/jenkins/init.groovy.d/01-credentials.groovy
sudo mv /home/ubuntu/04-seedJob.groovy /var/lib/jenkins/init.groovy.d/04-seedJob.groovy
sudo cp /home/ubuntu/03-approval.groovy /var/lib/jenkins/init.groovy.d/03-approval.groovy
sudo mv /home/ubuntu/seed.groovy /var/lib/jenkins/workspace/seed-job/seed.groovy
sudo chmod 755 /usr/local/bin/certbot_initial.sh
sudo chmod 755 /usr/local/bin/certbot_renewal.sh
sudo chmod 755 /var/lib/jenkins/init.groovy.d -R
sudo chmod 755 /var/lib/jenkins/workspace/seed-job/seed.groovy
sudo chown -R jenkins:jenkins /var/lib/jenkins
sudo systemctl restart jenkins
echo "Restarting Jenkins"
JENKINS_PW=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
echo "Jenkins password is $JENKINS_PW"
echo "All done!"