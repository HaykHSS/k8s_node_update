Run this script to start your k8s worker node upgrade process

Process is interactive so you need to perform actions in order to get desired result 

1. After running it you can choose full upgrade to do sequentially all the steps
2. You can stop the script after each step after which you can run it again and choose 'start from preferred step' to continute from last step
3. You need to provision node name on which you want do do upgrade


Before you do the update step you need to ensure that kubernetes repo was added to your package manager
use these commands to do this:
    - sudo apt-get update
    - sudo apt-get install -y apt-transport-https ca-certificates curl gpg
    - curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    - sudo apt-get update

