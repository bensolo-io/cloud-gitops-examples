variable "vpcConfig" {

}

variable "moduleName" {
  type        = string
  description = "name of current module, used in all resource names"
}

variable "stackVersion" {
  type        = string
  description = "version string used in all stack resource names"
}

variable "tags" {
  default = {
    "created-by" = "benji_lilley"
    "team"       = "product"
    "purpose"    = "product-development"
  }
}

variable "region" {

}

variable "commonVpcConfigs" {

}


locals {
  resourcePrefix = "${var.stackVersion}-${var.moduleName}"
}
