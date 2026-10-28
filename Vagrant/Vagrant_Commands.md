# Vagrant Commands


## Table Of Contents

- []()

---

## 

| Command                                           | What it does                              | When to use it                                    |
|---------------------------------------------------|-------------------------------------------|---------------------------------------------------|
| `vagrant init`                                    | Generate a new VagrantFile                | **Rarely** - When doesnt have  any VagrantFile    |
| `vagrant up vagrat_vm --provider=virtualbox`      |                                           |                                                   |

***[🔝 Table Of Contents](#table-of-contents)***

---



vagrant box add \
  --name ubuntu/jammy24-local \
  ./ubuntu-24.04.box \
  --provider virtualbox

vagrant status vagrat_vm
vagrant ssh vagrat_vm

ruby -c Vagrantfile
vagrant validate
vagrant box list
vagrant status asma-wp
vagrant global-status --prune
vagrant plugin list
vagrant box list

vagrant destroy asma-wp-test
vagrant provision nima-test-1 --provision-with nima-user