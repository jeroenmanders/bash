source "virtualbox-iso" "kube-master-and-worker" {
  vm_name                   = "kubernetes-base"
  guest_os_type             = "Ubuntu_64"
  headless                  = true
  iso_urls                  = "${ var.iso_urls }"
  iso_checksum              = "${ var.iso_checksum }"
  iso_target_path           = "${ var.iso_target_path }"
  guest_additions_mode      = "upload"
  output_directory          = "${ var.output_directory }"
  ssh_username              = "packer"
  ssh_password              = "packer"
  ssh_wait_timeout          = "600s"
  ssh_clear_authorized_keys = true
  shutdown_command          = "echo 'packer' | sudo -S /bin/sh -c '/usr/sbin/userdel -rf packer; /usr/sbin/shutdown -P now'"
  boot_command              = [
    "<esc><esc><enter><wait>",
    "/install/vmlinuz noapic",
    " initrd=/install/initrd.gz",
    " auto=true",
    " priority=critical",
    " hostname=packer-ubuntu",
    " passwd/user-fullname=packer",
    " passwd/username=packer",
    " passwd/user-password=packer",
    " passwd/user-password-again=packer",
    " preseed/url=http://{{.HTTPIP}}:{{.HTTPPort}}/preseed.cfg",
    " -- <enter>"
  ]
  boot_wait                 = "10s"
  http_directory            = "http"
  vboxmanage                = [
    ["modifyvm", "{{.Name}}", "--memory", "2048"],
    ["modifyvm", "{{.Name}}", "--cpus", "4"],
    ["modifyvm", "{{.Name}}", "--vrde", "off"],
    ["modifyvm", "{{.Name}}", "--audio", "none"],
    ["modifyvm", "{{.Name}}", "--nictype1", "virtio"],
    ["modifyvm", "{{.Name}}", "--usb", "off"],
    ["modifyvm", "{{.Name}}", "--vram", "12"]
  ]
}

build {
  sources = ["sources.virtualbox-iso.kube-master-and-worker"]
  provisioner "file" {
    source      = "scripts"
    destination = "/tmp/scripts"
  }
  provisioner "shell" {
    inline = [
      "cd /tmp/scripts",
      "echo 'packer' | sudo -S /tmp/scripts/install-base.sh '${ var.os_username }' '${ var.os_user_id }' '${ var.os_user_pub_key }' '${ var.os_group_id }'"
    ]
  }
}

