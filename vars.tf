variable "prefix" {
    description = "The prefix which should be used for all resources"
    default = "kavish"
}

variable "location" {
    description = "The Azure Region in which all resources should be created."
    default = "South Central US"
}

variable "vm_count" {
    description = "Number of Virtual Machines to be provisioned"
    default = 2
}

variable "username" {
    type = string
    default = "ubuntu"
}

variable "password" {
    type = string
    default = "Ubuntu@1234"
}