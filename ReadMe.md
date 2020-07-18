# AliDDNSBash

## 介绍

如果使用了阿里云（万网）的域名解析服务的话，那么就可以通过它提供的API，使用HTTP访问动态修改解析地址，以实现DDNS的功能。阿里云也提供了一些语言的SDK，但是并没有Shell版本的。

所以只能自力更生，写了一个Shell脚本来访问API。

注意：此脚本只实现了调用**修改域名解析记录**和**获取解析记录列表**的API的功能，并没有完整实现整个SDK。但是因为脚本已经实现了API的签名机制，所以很容易实现其他API的调用。

本脚本在**OpenWRT**中测试通过。（也就是在这种场合会连个Python都跑不了，而一定要使用Shell…）

参考：[阿里云解析API文档](https://help.aliyun.com/document_detail/29739.html)


## 功能

* 能在 OpenWRT 上原生的 ash 中执行。
* 仅在当前IP地址和域名解析设置不同时，发起更新请求。（本机当前IP地址通过[3322.org提供的API](http://members.3322.org/dyndns/getip) 进行查询，域名的解析设置通过API：*DescribeDomainRecordInfo* 查询。）
* **还没**在脚本中分析API执行的结果，只是单纯打印出来。

## 使用方法

1. 安装依赖

首先需要一个*shell*（目标是支持所有符合 POSIX 标准的 shell，在 *ash* 和 *bash* 上测试通过）。

然后安装*curl*，*openssl-util*。这些软件包在OpenWRT下可直接使用 *opkg* 命令安装。

2. 修改脚本的`setting`代码段，其中`DomainRecordId`不清楚的话暂时不用修改，`DNSServer`修改为你在万网上使用的DNS服务器。如:
```sh
AccessKeyId="MyID"
AccessKeySec="MySecret"
DomainRecordId="00000"
DomainRR="www"
DomainName="example.com"
DomainType="A"
DNSServer="dns9.hichina.com"
```

3. 如果不清楚DomainRecordId的话，修改`main`函数，在里面调用`describe_record`，如：
```sh
	main()
	{
		describe_record
		#update_record
	}
```
  然后执行这个脚本。如果没问题的话，就能获取到域名的所有解析记录的列表了：
```JSON
{"PageNumber":1,"TotalCount":1,"PageSize":1,"RequestId":"0000","DomainRecords":
  {"Record":[{"RR":"www","Status":"ENABLE","Value":"8.8.8.8",
  "RecordId":"21332133","Type":"A","DomainName":"example.com",
  "Locked":false,"Line":"default","TTL":"600"},]}
  }HttpCode:200
```
  上面的结果中，RecordId为*21332133*。得到结果后再修改`DomainRecordId`为正确的值。
  
4. 修改`main`函数：
```sh
	main()
	{
		#describe_record
		update_record
	}
```
  执行脚本即可。脚本会在本机IP地址和当前域名解析设置不同的时候调用API更新设置。
