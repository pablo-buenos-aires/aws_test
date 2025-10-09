terraform { # блок настройки терраформ
	required_version = ">= 1.2" # страховка от несовместимости кода со старой версией терраформ
	# офиц. плагин для авс, 6 версия актуальная
	required_providers { aws = {  source   = "hashicorp/aws",  version = "~> 6.15"  } }

	}

provider "aws" { region = "sa-east-1" } # блок провайдера