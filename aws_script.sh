AWS_REGION="us-east-1"
VPC_NAME="MY_VPC"
VPC_CIDR="10.0.0.0/16"
SUBNET_PUBLIC_CIDR="10.0.1.0/24"
SUBNET_PUBLIC_AZ="us-east-1a"
SUBNET_PUBLIC_NAME="PublicSubnet"
SUBNET_PRIVATE_CIDR="10.0.2.0/24"
SUBNET_PRIVATE_AZ="us-east-1b"
SUBNET_PRIVATE_NAME="PrivateSubnet"
IGW_ID_NAME="my_igw"
ROUTEPUB_TABLE_NAME="Public-rt"
ROUTE_TABLE_NAME="Private-rt"
NAT_NAME="my_nat"
PUBLIC_INSTANCE="Apache"
PRIVATE_INSTANCE="Tomcat"

# Create VPC
echo "Creating VPC in ap-south-1(Mumbai)"
VPC_ID=$(aws ec2 create-vpc  --cidr-block $VPC_CIDR  --query 'Vpc.{VpcId:VpcId}' --output text  --region $AWS_REGION)
echo "  VPC ID '$VPC_ID' CREATED in '$AWS_REGION' region."

# Add Name tag to VPC
aws ec2 create-tags  --resources $VPC_ID   --tags "Key=Name,Value=$VPC_NAME"  --region $AWS_REGION
echo "  VPC ID '$VPC_ID' NAMED as '$VPC_NAME'."

# Create Public Subnet
echo "Creating Public Subnet..."
SUBNET_PUBLIC_ID=$(aws ec2 create-subnet  --vpc-id $VPC_ID  --cidr-block $SUBNET_PUBLIC_CIDR --availability-zone $SUBNET_PUBLIC_AZ --query 'Subnet.{SubnetId:SubnetId}' --output text --region $AWS_REGION)
echo "  Subnet ID '$SUBNET_PUBLIC_ID' CREATED in '$SUBNET_PUBLIC_AZ'" "Availability Zone."

# Add Name tag to Public Subnet
aws ec2 create-tags --resources $SUBNET_PUBLIC_ID --tags "Key=Name,Value=$SUBNET_PUBLIC_NAME"  --region $AWS_REGION
echo "  Subnet ID '$SUBNET_PUBLIC_ID' NAMED as" "'$SUBNET_PUBLIC_NAME'."

# Create Private Subnet
echo "Creating Private Subnet..."
SUBNET_PRIVATE_ID=$(aws ec2 create-subnet  --vpc-id $VPC_ID  --cidr-block $SUBNET_PRIVATE_CIDR --availability-zone $SUBNET_PRIVATE_AZ --query 'Subnet.{SubnetId:SubnetId}' --output text --region $AWS_REGION)
echo "  Subnet ID '$SUBNET_PRIVATE_ID' CREATED in '$SUBNET_PRIVATE_AZ'" "Availability Zone."

# Add Name tag to Private Subnet
aws ec2 create-tags --resources $SUBNET_PRIVATE_ID --tags "Key=Name,Value=$SUBNET_PRIVATE_NAME"  --region $AWS_REGION
echo "  Subnet ID '$SUBNET_PRIVATE_ID' NAMED as" "'$SUBNET_PRIVATE_NAME'."

# Create Internet gateway
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway  --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' --output text  --region $AWS_REGION)
echo "  Internet Gateway ID '$IGW_ID' CREATED."

# Attach Internet gateway to your VPC
aws ec2 attach-internet-gateway  --vpc-id $VPC_ID --internet-gateway-id $IGW_ID  --region $AWS_REGION
echo "  Internet Gateway ID '$IGW_ID' ATTACHED to VPC ID '$VPC_ID'."

# Add Name tag to Internet gateway
aws ec2 create-tags --resources $IGW_ID  --tags "Key=Name,Value=$IGW_ID_NAME"  --region $AWS_REGION
echo "  Internet Gateway ID '$IGW_ID' NAMED as '$IGW_ID_NAME'."

# Create Route Table
echo "Creating Route Table..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.{RouteTableId:RouteTableId}' --output text   --region $AWS_REGION)
echo "  Route Table ID '$ROUTE_TABLE_ID' CREATED."

# Add Name tag to Route Table
aws ec2 create-tags --resources $ROUTE_TABLE_ID  --tags "Key=Name,Value=$ROUTEPUB_TABLE_NAME"  --region $AWS_REGION
echo "   Route Table ID '$ROUTE_TABLE_ID' NAMED as '$ROUTEPUB_TABLE_NAME'."

# Create route to Internet Gateway
RESULT=$(aws ec2 create-route  --route-table-id $ROUTE_TABLE_ID  --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID  --region $AWS_REGION)
echo "  Route to '0.0.0.0/0' via Internet Gateway ID '$IGW_ID' ADDED to" "Route Table ID '$ROUTE_TABLE_ID'."


# Associate Public Subnet with Route Table
RESULT=$(aws ec2 associate-route-table  --subnet-id $SUBNET_PUBLIC_ID --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION)
echo "  Public Subnet ID '$SUBNET_PUBLIC_ID' ASSOCIATED with Route Table ID" "'$ROUTE_TABLE_ID'."

# Enable Auto-assign Public IP on Public Subnet
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUBLIC_ID --map-public-ip-on-launch  --region $AWS_REGION
echo "  'Auto-assign Public IP' ENABLED on Public Subnet ID" "'$SUBNET_PUBLIC_ID'."

# Allocate Elastic IP Address for NAT Gateway
echo "Creating NAT Gateway..."
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query '{AllocationId:AllocationId}' --output text   --region $AWS_REGION)
echo "  Elastic IP address ID '$EIP_ALLOC_ID' ALLOCATED."

# Create NAT Gateway
NAT_GW_ID=$(aws ec2 create-nat-gateway --subnet-id $SUBNET_PUBLIC_ID --allocation-id $EIP_ALLOC_ID --query 'NatGateway.{NatGatewayId:NatGatewayId}' --output text  --region $AWS_REGION)
echo " Created NAT Gateway '$NAT_GW_ID'."

sleep 40

# Add Name tag to NAT Gatway
aws ec2 create-tags --resources $NAT_GW_ID  --tags "Key=Name,Value=$NAT_NAME"  --region $AWS_REGION
echo "   Route Table ID '$NAT_GW_ID' NAMED as '$NAT_NAME'."

# Create route to NAT Gateway
MAIN_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables  --filters Name=vpc-id,Values=$VPC_ID Name=association.main,Values=true --query 'RouteTables[*].{RouteTableId:RouteTableId}' --output text --region $AWS_REGION)
echo "  Main Route Table ID is '$MAIN_ROUTE_TABLE_ID'."
RESULT=$(aws ec2 create-route  --route-table-id $MAIN_ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $NAT_GW_ID --region $AWS_REGION)
echo "  'Route to '0.0.0.0/0' via NAT Gateway with ID '$NAT_GW_ID' ADDED to" "Route Table ID '$MAIN_ROUTE_TABLE_ID'."

# Add Name tag to Route Table
aws ec2 create-tags --resources $MAIN_ROUTE_TABLE_ID  --tags "Key=Name,Value=$ROUTE_TABLE_NAME"  --region $AWS_REGION
echo " Route Table ID '$MAIN_ROUTE_TABLE_ID' NAMED as '$ROUTE_TABLE_NAME'."

#Creating Security groups
echo "Creating Security groups"
SGSSH=$(aws ec2 create-security-group --group-name SSHAccess --description "My security gp " --vpc-id $VPC_ID --output text)
aws ec2 authorize-security-group-ingress --group-id $SGSSH --protocol tcp --port 22 --cidr 0.0.0.0/0 
aws ec2 authorize-security-group-ingress --group-id $SGSSH --protocol tcp --port 80 --cidr 0.0.0.0/0
echo " Created Security Groups '$SGSSH'."

#Creating Security groups for private instance
echo "Creating Security groups"
SGSSH_PRI=$(aws ec2 create-security-group --group-name PrivateSSHAccess --description "My security gp for pri " --vpc-id $VPC_ID --output text)
aws ec2 authorize-security-group-ingress --group-id $SGSSH_PRI --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SGSSH_PRI --protocol tcp --port 8080 --cidr 0.0.0.0/0
echo " Created Security Groups '$SGSSH_PRI'."


sudo chmod 400 project-key-pair.pem 


#Creating Tomcat Instance in private subnet
echo "Creating tomcat instance"
TOMCAT_ID=$(aws ec2 run-instances --image-id ami-052efd3df9dad4825 --count 1 --instance-type t2.micro --key-name  project-key-pair --security-group-ids $SGSSH_PRI --subnet-id $SUBNET_PRIVATE_ID --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MyInstance}]' --user-data file://docker.sh )

# Add Name tag to Private instance
#aws ec2 create-tags --resources $TOMCAT_ID --tags "Key=Name,Value=$PRIVATE_INSTANCE"  --region $AWS_REGION
#echo "  PRIVATE INSTANCE '$TOMCAT_ID' NAMED as '$PRIVATE_INSTANCE'."

echo "wait for few second.."
sleep 120

#echo " Instance Created  '$TOMCAT_ID'"\

#Creating Apache Instance in public subnet
echo "Creating apache instance"
APACHE_ID=$(aws ec2 run-instances --image-id ami-052efd3df9dad4825 --count 1 --instance-type t2.micro --key-name  project-key-pair --security-group-ids $SGSSH --subnet-id $SUBNET_PUBLIC_ID --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=webserver}]' --user-data file://docker.sh )

echo "wait for few second.."
sleep 120

#echo "First Instance Created '$APACHE_ID'"


#Add Name tag to Public instance
#aws ec2 create-tags --resources $APACHE_ID --tags "Key=Name,Value=$PUBLIC_INSTANCE"  --region $AWS_REGION
#echo " PUBLIC INSTANCE  '$APACHE_ID' NAMED as '$PUBLIC_INSTANCE'."


echo "COMPLETED"
