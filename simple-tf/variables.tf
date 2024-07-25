variable "Location" {
  default = "uksouth"
}

variable "VnetResourceGroup" {
  type = string
}

variable "VnetName" {
  type = string
}

variable "VnetAddressSpace" {
  type = string
}

variable "BackendSubnetName" {
  type = string
}

variable "BackendSubnetIPRange" {
  type = string
}

variable "DatabaseSubnetName" {
  type = string
}

variable "DatabaseSubnetIPRange" {
  type = string
}

variable "DatabaseName" {
  type = string
}

variable "DatabaseAdmin" {
  type    = string
  default = "psqladmin"
}

variable "DatabasePassword" {
  type = string
}

variable "DatabaseResourceGroup" {
  type = string
}

variable "AKSResourceGroup" {
  type = string
}

variable "AKSName" {
  type = string
}

variable "AKSAuthorizedIPs" {
  type = string
}

variable "AKSNodeSKU" {
  type    = string
  default = "standard_b2as_v2"
}

variable "AKSNodeMaxCount" {
  type = number
}

variable "AKSVersion" {
  type = string
}