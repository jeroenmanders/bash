variable "os_username" {
  description = "Username of the user that will be added to the virtual machine."
  type        = string
}

variable "os_user_id" {
  description = "User ID of the user that will be added to the virtual machine."
  type        = string
}

variable "os_user_pub_key" {
  description = "Public key to grant the user access to the instances."
  type        = string
}

variable "iso_checksum" {
  description = "Checksum to verify the ISO with."
  type        = string
  default     = "sha256:f11bda2f2caed8f420802b59f382c25160b114ccc665dbac9c5046e7fceaced2"
}

variable "iso_urls" {
  description = "List with the locations of the base ISO. The first ISO found will be used."
  type        = list(string)
  default     = [
    "../../../local-resources/virtualbox/iso/ubuntu-20.04.1-legacy-server-amd64.iso",
    "https://cdimage.ubuntu.com/ubuntu-legacy-server/releases/20.04/release/ubuntu-20.04.1-legacy-server-amd64.iso"
  ]
}

variable "iso_target_path" {
  description = ""
  type        = string
  default     = "../../../local-resources/virtualbox/iso/ubuntu-20.04.1-legacy-server-amd64.iso"
}

variable "output_directory" {
  description = "Directory where to create the image in."
  type        = string
  default     = "../../../local-resources/virtualbox/kubernetes-base"
}

