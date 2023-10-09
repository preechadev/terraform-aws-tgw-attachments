
// Additional codes for creating TGW and attachements
# Creation of the TGW and the attachments

# To create the TGW
resource "aws_ec2_transit_gateway" "tgw-central" {
  description = var.tgw-name
  tags = {
    Name = var.tgw-name
  }
}

# To create the TGW route table for Check Point
resource "aws_ec2_transit_gateway_route_table" "tgw-rt-security" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw-central.id

  tags = {
    Name = "tgw-rtb-security"
  }
  depends_on = [aws_ec2_transit_gateway.tgw-central]  
}

# To update the TGW route table for Check Point
resource "aws_ec2_transit_gateway_route" "rt-security-to-vpcs" {
  count = length(var.spoke-env)
  destination_cidr_block         = lookup(var.spoke-env,count.index)[1]
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-spoke-attachments[count.index].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw-rt-security.id
}

# To attach the TGW subnets to TGW attachment with appliance mode enabled
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-security-attachment" {
  subnet_ids         = [element(module.launch_vpc.tgw_subnets_ids_list, 0),element(module.launch_vpc.tgw_subnets_ids_list, 1),element(module.launch_vpc.tgw_subnets_ids_list, 2)]
  transit_gateway_id = aws_ec2_transit_gateway.tgw-central.id
  vpc_id             = module.launch_vpc.vpc_id

  appliance_mode_support = "enable"  
  transit_gateway_default_route_table_association = false

  tags = {
    Name = "tgw-attach-vpc-security"
  }
  depends_on = [aws_ec2_transit_gateway.tgw-central,module.launch_vpc]
}

# To create the TGW route table association for Check Point attachment
resource "aws_ec2_transit_gateway_route_table_association" "tgw-rt-security-assoc" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw-rt-security.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-security-attachment.id
  depends_on = [aws_ec2_transit_gateway.tgw-central,aws_ec2_transit_gateway_vpc_attachment.tgw-security-attachment]
}


# To create the TGW attachment for spoke
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-spoke-attachments" {
  count              = length(var.spoke-env)
  subnet_ids         = [aws_subnet.net-tgw-spoke[count.index].id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw-central.id
  vpc_id             = var.vpc_cidr
  transit_gateway_default_route_table_association = false
    
  tags = {
    Name = "tgw-attach-${lookup(var.spoke-env,count.index)[0]}"
    "Resource Group" = "rg-${lookup(var.spoke-env,count.index)[0]}"
  }
  depends_on = [aws_ec2_transit_gateway.tgw-central,aws_subnet.net-tgw-spoke]
}

# To create the TGW route table for spoke
resource "aws_ec2_transit_gateway_route_table" "tgw-rt-spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw-central.id

  tags = {
    Name = "tgw-rtb-spoke"
  }
  depends_on = [aws_ec2_transit_gateway.tgw-central]  
}

# To associate the TGW route table to spoke
resource "aws_ec2_transit_gateway_route_table_association" "tgw-rt-spoke-assoc" {
  count              = length(var.spoke-env)
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw-rt-spoke.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-spoke-attachments[count.index].id
  depends_on = [aws_ec2_transit_gateway.tgw-central,aws_ec2_transit_gateway_vpc_attachment.tgw-spoke-attachments]
}

# TGW route table for spoke, to have default route to hit TGW attachment
resource "aws_ec2_transit_gateway_route" "rt-to-security-vpc" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-security-attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw-rt-spoke.id
}

