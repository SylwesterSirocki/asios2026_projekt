// credencjale dla maszyn wirtualnych
variable "my_public_ip" {
  description = "Tutaj jest adres maszyny z której bede sie laczył z maszynami wirt"
  type        = string
  default     = "188.47.103.225/32"
}

variable "front_admin_username" {
  description = "login administratora dla frontend"
  type        = string
  default     = "frontadmin"
}

variable "front_admin_pass" {
  description = "haslo administratora dla frontend"
  type        = string
  sensitive   = true
}

variable "back_admin_username" {
  description = "login administratora dla backend"
  type        = string
  default     = "backadmin"
}

variable "back_admin_pass" {
  description = "haslo administratora dla backend"
  type        = string
  sensitive   = true
}

