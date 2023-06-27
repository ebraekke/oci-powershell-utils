
## How to connect to a non IaaS based MySQL ?  

```powershell 
$connString
<<
mysql://10.0.1.199:3306

$parts = $connString.Split('://')

$parts
<<
mysql
10.0.1.199:3306

$details = $parts[1].Split(':')

$details
<<
10.0.1.199
3306
```

The IP or host name is the the target address of the connection to be used for bastion creation.
