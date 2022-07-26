AWS_REGION="us-east-1"
VPC_NAME="Project-VPC"
VPC_CIDR="10.0.0.0/16"
SUBNET_PUBLIC_CIDR="10.0.0.0/24"
SUBNET_PUBLIC_AZ="us-east-1a"
SUBNET_PUBLIC_NAME="public-subnet"
SUBNET_PRIVATE_CIDR="10.0.1.0/24"
SUBNET_PRIVATE_AZ="us-east-1b"
SUBNET_PRIVATE_NAME="private-subnet"
PUBLIC_KP="public-key-pair"
PRIVATE_KP="private-key-pair"
AMI_ID="ami-068257025f72f470d"



# VPC -->

echo "Creating VPC in preferred region..."
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --query 'Vpc.{VpcId:VpcId}' --output text --region $AWS_REGION)
echo "  VPC ID '$VPC_ID' CREATED in '$AWS_REGION' region."

# Adding Name tag to VPC -->

aws ec2 create-tags --resources $VPC_ID --tags "Key=Name,Value=$VPC_NAME" --region $AWS_REGION
echo "  VPC ID '$VPC_ID' NAMED as '$VPC_NAME'."

# Public Subnet -->

echo "Creating Public Subnet..."
SUBNET_PUBLIC_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_PUBLIC_CIDR --availability-zone $SUBNET_PUBLIC_AZ --query 'Subnet.{SubnetId:SubnetId}' --output text --region $AWS_REGION)
echo "  Subnet ID '$SUBNET_PUBLIC_ID' CREATED in '$SUBNET_PUBLIC_AZ'" "Availability Zone."

# Adding Name tag to Public Subnet -->

aws ec2 create-tags --resources $SUBNET_PUBLIC_ID --tags "Key=Name,Value=$SUBNET_PUBLIC_NAME" --region $AWS_REGION
echo "  Subnet ID '$SUBNET_PUBLIC_ID' NAMED as" "'$SUBNET_PUBLIC_NAME'."

# Private Subnet -->

echo "Creating Private Subnet..."
SUBNET_PRIVATE_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_PRIVATE_CIDR --availability-zone $SUBNET_PRIVATE_AZ --query 'Subnet.{SubnetId:SubnetId}' --output text --region $AWS_REGION)
echo "  Subnet ID '$SUBNET_PRIVATE_ID' CREATED in '$SUBNET_PRIVATE_AZ'" "Availability Zone."

# Adding Name tag to Private Subnet -->

aws ec2 create-tags --resources $SUBNET_PRIVATE_ID --tags "Key=Name,Value=$SUBNET_PRIVATE_NAME" --region $AWS_REGION
echo "  Subnet ID '$SUBNET_PRIVATE_ID' NAMED as '$SUBNET_PRIVATE_NAME'."

# Internet gateway -->

echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' --output text --region $AWS_REGION)
echo "  Internet Gateway ID '$IGW_ID' CREATED."

# Attaching Internet gateway to VPC -->

aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $AWS_REGION
echo "  Internet Gateway ID '$IGW_ID' ATTACHED to VPC ID '$VPC_ID'."

# Creating Route Table -->

echo "Creating Route Table..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.{RouteTableId:RouteTableId}' --output text --region $AWS_REGION)
echo "  Route Table ID '$ROUTE_TABLE_ID' CREATED."

# Creating route to Internet Gateway -->

RESULT=$(aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $AWS_REGION)
echo "  Route to '0.0.0.0/0' via Internet Gateway ID '$IGW_ID' ADDED to" "Route Table ID '$ROUTE_TABLE_ID'."

# Associating Public Subnet with Route Table -->

RESULT=$(aws ec2 associate-route-table --subnet-id $SUBNET_PUBLIC_ID --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION)
echo "  Public Subnet ID '$SUBNET_PUBLIC_ID' ASSOCIATED with Route Table ID" "'$ROUTE_TABLE_ID'."

# Enabling Auto-assign Public IP on Public Subnet -->

aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUBLIC_ID --map-public-ip-on-launch --region $AWS_REGION
echo "  'Auto-assign Public IP' ENABLED on Public Subnet ID" "'$SUBNET_PUBLIC_ID'."

# Allocating Elastic IP Address for NAT Gateway -->

echo "Allocating Elastic IP Address for NAT Gateway.... "
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query '{AllocationId:AllocationId}' --output text --region $AWS_REGION)
echo "  Elastic IP address ID '$EIP_ALLOC_ID' ALLOCATED."

# Creating NAT Gateway -->

echo "Creating NAT Gateway.... "
NAT_GW_ID=$(aws ec2 create-nat-gateway --subnet-id $SUBNET_PUBLIC_ID --allocation-id $EIP_ALLOC_ID --query 'NatGateway.{NatGatewayId:NatGatewayId}' --output text --region $AWS_REGION)

sleep 2m

MAIN_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID Name=association.main,Values=true --query 'RouteTables[*].{RouteTableId:RouteTableId}' --output text --region $AWS_REGION)
echo "  Main Route Table ID is '$MAIN_ROUTE_TABLE_ID'."

RESULT=$(aws ec2 create-route --route-table-id $MAIN_ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $NAT_GW_ID --region $AWS_REGION)
echo "  Route to '0.0.0.0/0' via NAT Gateway with ID '$NAT_GW_ID' ADDED to" "Route Table ID '$MAIN_ROUTE_TABLE_ID'."
echo "COMPLETED"



#Creating Security Group -->

echo "Creating Security Group...."
aws ec2 create-security-group --group-name Security-Group --description "My security group" --vpc-id $VPC_ID --region $AWS_REGION
SG_ID=$(aws ec2 describe-security-groups --filter Name=vpc-id,Values=$VPC_ID Name=group-name,Values=Security-Group --query 'SecurityGroups[*].[GroupId]' --output text)
echo "security group is created.. ID is '$SG_ID'...."


#Authorizing security group --->

aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 182.64.71.201/32
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0



# Creating key pair for public subnet -->

echo "Creating key pair for public subnet....."
aws ec2 create-key-pair --key-name $PUBLIC_KP --query 'KeyMaterial' --output text > $PUBLIC_KP.pem
echo "key pair created..."

sudo chmod 400 $PUBLIC_KP.pem


# Creating key pair for private subnet -->

echo "Creating key pair for private subnet....."
aws ec2 create-key-pair --key-name $PRIVATE_KP --query 'KeyMaterial' --output text > $PRIVATE_KP.pem
echo "key pair created..."

sudo chmod 400 $PRIVATE_KP.pem

#Creating EC2 instance in private subnet -->

echo "EC2 instance 2 in private subnet is creating..."
EC2_ID2=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.micro --key-name $PRIVATE_KP --security-group-ids $SG_ID --subnet-id $SUBNET_PRIVATE_ID --user-data file://Docker.sh)


sleep 2m
echo "EC2 instance 2 in private subnet is created...ID is '$EC2_ID2'...."

AWS_PV_INID=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[Placement.AvailabilityZone, State.Name, InstanceId]' --output text | grep $SUBNET_PRIVATE_AZ | grep running | awk '{print $3}')
echo "PRIVATE INSTANCE ID is '$AWS_PV_INID' CREATED"

Private_IP=$(aws ec2 describe-instances --filters "Name=instance-id,Values=$AWS_PV_INID" --query 'Reservations[*].Instances[*].[PrivateIpAddress]' --output text)
echo "PRIVATE IP is '$Private_IP' is created"

#Creating EC2 instance in public subnet -->

echo "EC2 instance 1 in public subnet is creating..."
EC2_ID1=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.micro --key-name $PUBLIC_KP --security-group-ids $SG_ID --subnet-id $SUBNET_PUBLIC_ID --user-data file://Docker.sh)

sleep 2m
echo "EC2 instance 1 in public subnet is created...ID is '$EC2_ID1'...."

echo "virtual hosting done successfully."
