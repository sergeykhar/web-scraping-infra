#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting user-data script at $(date)"

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Create directories
mkdir -p /home/ec2-user/scripts
mkdir -p /home/ec2-user/output
mkdir -p /home/ec2-user/logs

# Create run-scraper script
cat << 'SCRIPT' > /home/ec2-user/scripts/run-scraper.sh
#!/bin/bash
set -e

#####################################
# Configuration (injected by Terraform)
#####################################
AWS_REGION="${aws_region}"
ECR_REPOSITORY="${ecr_repository}"
S3_BUCKET="${s3_bucket}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE=/home/ec2-user/logs/scraper_$${TIMESTAMP}.log

#####################################
# Functions
#####################################
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

#####################################
# Main Script
#####################################
log "=============================================="
log "Starting web scraping job"
log "=============================================="

# Login to ECR
log "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY

# Pull latest image
log "Pulling latest Docker image..."
docker pull $ECR_REPOSITORY:latest

# Clean output directory
log "Cleaning output directory..."
rm -rf /home/ec2-user/output/*

# Run scraper
log "Running scraper container..."
docker run --rm \
  -v /home/ec2-user/output:/web-scraping/output \
  $ECR_REPOSITORY:latest

# Check if output file exists
if [ ! -f /home/ec2-user/output/players_current_list.json ]; then
    log "ERROR: Output file not found!"
    exit 1
fi

# Get file size
FILE_SIZE=$(du -h /home/ec2-user/output/players_current_list.json | cut -f1)
log "Output file size: $FILE_SIZE"

# Upload to S3 with timestamp
log "Uploading to S3..."
aws s3 cp /home/ec2-user/output/players_current_list.json \
    "s3://$S3_BUCKET/raw/players/players_$${TIMESTAMP}.json"

# Also upload as latest
aws s3 cp /home/ec2-user/output/players_current_list.json \
    "s3://$S3_BUCKET/raw/players/players_latest.json"

log "=============================================="
log "Web scraping job completed successfully!"
log "=============================================="
SCRIPT

# Make script executable
chmod +x /home/ec2-user/scripts/run-scraper.sh
chown -R ec2-user:ec2-user /home/ec2-user/scripts
chown -R ec2-user:ec2-user /home/ec2-user/output
chown -R ec2-user:ec2-user /home/ec2-user/logs

# Create a small systemd service to ensure permissions persist on reboot
cat > /etc/systemd/system/scraper-perms.service <<'UNIT'
[Unit]
Description=Ensure scraper script permissions
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/chown -R ec2-user:ec2-user /home/ec2-user/scripts /home/ec2-user/output /home/ec2-user/logs
ExecStart=/bin/chmod +x /home/ec2-user/scripts/run-scraper.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

# Reload systemd and enable the service so it runs at boot
systemctl daemon-reload
systemctl enable --now scraper-perms.service || true

echo "User-data script completed at $(date)"
