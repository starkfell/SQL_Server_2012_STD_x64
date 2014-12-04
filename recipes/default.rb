#
# Cookbook Name:: SQL_Server_2012_STD_x64
# Recipe:: default
#
# Copyright (c) 2014 Ryan Irujo, All Rights Reserved.
#
# <USERNAME>        - must be replaced with the local user the 'encrypted_sql2012_data_bag_secret' is kept under.
# <WEB_SERVER_NAME> - must be replaced with the name of the Web Server you are hosting the SQL2012 ISO on.

# Declaring Variables
secret_key        = Chef::EncryptedDataBagItem.load_secret("C:\\Users\\<USERNAME>\\.chef\\encrypted_sql2012_data_bag_secret")
usernames         = data_bag_item('SQL2012', 'sql_service_account_usernames')
passwords         = Chef::EncryptedDataBagItem.load('SQL2012', 'sql_service_account_passwords', secret_key)
iso_url           = "http://<WEB_SERVER_NAME>/packages/en_sql_server_2012_standard_edition_with_sp1_x64_dvd_1228198.iso"
iso_path          = "C:\\Temp\\en_sql_server_2012_standard_edition_with_sp1_x64_dvd_1228198.iso"
sql_svc_act       = usernames['sql_server_service_username']
sql_svc_pass      = passwords['sql_server_service_password']
sql_sysadmins     = usernames['sql_sysadmins_username']
sql_agent_svc_act = "NT AUTHORITY\\Network Service"

# Creating a Temporary Directory to work from.
directory "C:\\Temp\\" do
	rights :full_control, "#{sql_svc_act}"
	inherits true
	action :create
end

# Download the SQL Server 2012 Standard ISO from a Web Share.
powershell_script 'Download SQL Server 2012 STD ISO' do
	code <<-EOH
		$Client = New-Object System.Net.WebClient
		$Client.DownloadFile("#{iso_url}", "#{iso_path}")
		EOH
	guard_interpreter :powershell_script
	not_if { File.exists?(iso_path)}
end

# Mounting the SQL Server 2012 SP1 Standard ISO.
powershell_script 'Mount SQL Server 2012 STD ISO' do
	code <<-EOH
		Mount-DiskImage -ImagePath "C:\\Temp\\en_sql_server_2012_standard_edition_with_sp1_x64_dvd_1228198.iso"
        if ($? -eq $True)
		{
			echo "SQL Server 2012 STD ISO was mounted Successfully." > C:\\Temp\\SQL_Server_2012_STD_ISO_Mounted_Successfully.txt
			exit 0;
		}
		
		if ($? -eq $False)
        {
			echo "The SQL Server 2012 STD ISO Failed was unable to be mounted." > C:\\Temp\\SQL_Server_2012_STD_ISO_Mount_Failed.txt
			exit 2;
        }
		EOH
	guard_interpreter :powershell_script
	not_if '($SQL_Server_ISO_Drive_Letter = (gwmi -Class Win32_LogicalDisk | Where-Object {$_.VolumeName -eq "SQLServer"}).VolumeName -eq "SQLServer")'
end

# Installing SQL Server 2012 Standard.
powershell_script 'Install SQL Server 2012 STD x64' do
	code <<-EOH
		$SQL_Server_ISO_Drive_Letter = (gwmi -Class Win32_LogicalDisk | Where-Object {$_.VolumeName -eq "SQLServer"}).DeviceID
		cd $SQL_Server_ISO_Drive_Letter\\
		$Install_SQL = ./Setup.exe /q /ACTION=Install /FEATURES=SQL /INSTANCENAME=MSSQLSERVER /SQLSVCACCOUNT="#{sql_svc_act}" /SQLSVCPASSWORD="#{sql_svc_pass}" /SQLSYSADMINACCOUNTS="#{sql_sysadmins}" /AGTSVCACCOUNT="#{sql_agent_svc_act}" /IACCEPTSQLSERVERLICENSETERMS
		$Install_SQL > C:\\Temp\\SQL_Server_2012_STD_Install_Results.txt
		EOH
	guard_interpreter :powershell_script
end


# Dismounting the SQL Server 2012 STD ISO.
powershell_script 'Dismount SQL Server 2012 STD ISO' do
	code <<-EOH
		Dismount-DiskImage -ImagePath "#{iso_path}"
		EOH
	guard_interpreter :powershell_script
	only_if { File.exists?(iso_path)}
end


# Removing the SQL Server 2012 STD ISO from the Temp Directory.
powershell_script 'Delete SQL Server 2012 STD ISO' do
	code <<-EOH
		[System.IO.File]::Delete("#{iso_path}")
		EOH
	guard_interpreter :powershell_script
	only_if { File.exists?(iso_path)}
end
