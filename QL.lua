-- Version 0.2
package.cpath=".\\?.dll;.\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\?.dll;C:\\Program Files (x86)\\Lua\\5.1\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\?.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\loadall.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\loadall.dll;C:\\Program Files\\Lua\\5.1\\?.dll;C:\\Program Files\\Lua\\5.1\\?51.dll;C:\\Program Files\\Lua\\5.1\\clibs\\?.dll;C:\\Program Files\\Lua\\5.1\\clibs\\?51.dll;C:\\Program Files\\Lua\\5.1\\loadall.dll;C:\\Program Files\\Lua\\5.1\\clibs\\loadall.dll"..package.cpath
package.path=package.path..";.\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?\\init.lua;C:\\Program Files (x86)\\Lua\\5.1\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\?\\init.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?.luac;C:\\Program Files\\Lua\\5.1\\lua\\?.lua;C:\\Program Files\\Lua\\5.1\\lua\\?\\init.lua;C:\\Program Files\\Lua\\5.1\\?.lua;C:\\Program Files\\Lua\\5.1\\?\\init.lua;C:\\Program Files\\Lua\\5.1\\lua\\?.luac;"
require"bit"
require"socket"
--require"iuplua"
--require"iupluacontrols"
function sendLimit(class,security,direction,price,volume,account,client_code,comment)
	-- отправка лимитированной заявки
	-- все параметры кроме кода клиента и коментария должны быть не нил
	-- ВАЖНО! цена должна быть стрингом с количеством знаков после точки для данной бумаги
	-- если код клиента нил - подлставляем счет
	-- Данная функция возвращает 3 параметра 
	--     1. Результат проверки заявки сервером Квик (true\false)
	--     2. ID присвоенный транзакции
	--     3. Ответноге сообщение сервера Квик либо строку с параметрами транзакции
	if (class==nil or security==nil or direction==nil or price==nil or volume==nil or account==nil) then
		return false,0,"QL.sendLimit(): Can`t send order. Nil parameters."
	end
	local trans_id=math.random(2000000000)
	local transaction={
		["TRANS_ID"]=tostring(trans_id),
		["ACTION"]="NEW_ORDER",
		["CLASSCODE"]=class,
		["SECCODE"]=security,
		["OPERATION"]=direction,
		["QUANTITY"]=volume,
		["PRICE"]=price,
		["ACCOUNT"]=account
	}
	if comment~=nil then
		transaction.comment=comment
	end
	if client_code==nil then
		transaction.client_code=account
	else
		transaction.client_code=client_code
	end
	local res=sendTransaction(transaction)
	if res~="" then
		return false,trans_id, "QL.sendLimit():"..res
	else
		return true,trans_id, "QL.sendLimit(): Limit order sended sucesfully. Class="..class.." Sec="..security.." Dir="..direction.." Price="..price.." Vol="..volume.." Acc="..account.." Trans_id="..trans_id
	end
end
function sendMarket(class,security,direction,volume,account,client_code,comment)
	-- отправка рыночной заявки
	-- все параметры кроме кода клиента и коментария должны быть не нил
	-- если код клиента нил - подлставляем счет
	-- Данная функция возвращает 3 параметра 
	--     1. Результат проверки заявки сервером Квик (true\false)
	--     2. ID присвоенный транзакции
	--     3. Ответноге сообщение сервера Квик либо строку с параметрами транзакции
	if (class==nil or security==nil or direction==nil  or volume==nil or account==nil) then
		return false,0,"QL.sendMarket(): Can`t send order. Nil parameters."
	end
	local FUT_OPT_CLASSES="FUTUX,OPTUX,SPBOPT,SPBFUT"
	local trans_id=math.random(2000000000)
	local transaction={
		["TRANS_ID"]=tostring(trans_id),
		["ACTION"]="NEW_ORDER",
		["CLASSCODE"]=class,
		["SECCODE"]=security,
		["OPERATION"]=direction,
		["TYPE"]="M",
		["QUANTITY"]=volume,
		["ACCOUNT"]=account
	}
	if comment~=nil then
		transaction.comment=comment
	end
	if client_code==nil then
		transaction.client_code=account
	else
		transaction.client_code=client_code
	end
	if string.find(FUT_OPT_CLASSES,class)~=nil then
		if direction=="B" then
			transaction.price=getParamEx(class,security,"PRICEMAX").param_image
		else
			transaction.price=getParamEx(class,security,"PRICEMIN").param_image
		end
	else
		transaction.price="0"
	end
	local res=sendTransaction(transaction)
	if res~="" then
		return false,trans_id, "QL.sendMarket():"..res
	else
		return true,trans_id, "QL.sendMarket(): Market order sended sucesfully. Class="..class.." Sec="..security.." Dir="..direction.." Vol="..volume.." Acc="..account.." Trans_id="..trans_id
	end
end
function moveOrders()
	-- перемещение заявки
	-- ВНИМАНИЕ! Доступна только на срочной секции (FORTS,FOUX)
end
function sendRPS(class,security,direction,price,volume,account,client_code,partner)
    -- функция отправки заявки на внебиржевую сделку
	if (class==nil or security==nil or direction==nil or price==nil or volume==nil or account==nil or partner==nil) then
		return false,"QL.sendRPS(): Can`t send order. Nil parameters."
	end
	--local trans_id=tostring(math.ceil(os.clock()))..tostring(math.random(os.clock()))
	local trans_id=math.random(2000000000)
	local transaction={
		["TRANS_ID"]=tostring(trans_id),
		["ACTION"]="NEW_NEG_DEAL",
		["CLASSCODE"]=class,
		["SECCODE"]=security,
		["OPERATION"]=direction,
		["QUANTITY"]=volume,
		["PRICE"]=price,
		["ACCOUNT"]=account,
		["PARTNER"]=partner,
		["SETTLE_CODE"]="B0"
	}
	if client_code==nil then
		transaction.client_code=account
	else
		transaction.client_code=client_code
	end
	local res=sendTransaction(transaction)
	if res~="" then
		return false,trans_id, "QL.sendRPS():"..res
	else
		return true,trans_id, "QL.sendRPS(): RPS order sended sucesfully. Class="..class.." Sec="..security.." Dir="..direction.." Price="..price.." Vol="..volume.." Acc="..account.." Partner="..partner.." Trans_id="..trans_id
	end
end
function sendReportOnRPS(class,operation,key)
    -- отправка отчета по сделки для исполнения
	if(class==nil or operation==nil or key==nil) then
		return false,"QL.sendRPS(): Can`t send order. Nil parameters."
	end
	--local trans_id=tostring(math.ceil(os.clock()))..tostring(math.random(os.clock()))
	local trans_id=math.random(2000000000)
	local transaction={
		["TRANS_ID"]=tostring(trans_id),
		["ACTION"]="NEW_REPORT",
		["CLASSCODE"]=class,
		["NEG_TRADE_OPERATION"]=operation,
		["NEG_TRADE_NUMBER"]=key
	}
	local res=sendTransaction(transaction)
	if res~="" then
		return false,trans_id, "QL.sendReportOnRPS():"..res
	else
		return true,trans_id, "QL.sendReportOnRPS(): ReportOnRPS order sended sucesfully. Class="..class.." Oper="..operation.." Key="..key.." Trans_id="..trans_id
	end
end
function killOrder(class,security,orderkey)
	
	-- функция отмены лимитированной заявки по номеру
	-- ВАЖНО! Данная функция не гарантирует снятие заявки
	-- Возвращает сообщение сервера в случае ошибки выявленной сервером Квик либо строку с информацией о транзакции
	if (class==nil or security==nil or orderkey==nil) then
		return "QL.killOrder(): Can`t kill order. Nil parameters."
	end
	if orderkey==0 then
		return "QL.killOrder(): Can`t kill order. OrderKey=0."
	end
	local trans_id=math.random(2000000000)
	local transaction={
		["TRANS_ID"]=tostring(trans_id),
		["CLASSCODE"]=class,
		["SECCODE"]=security,
		["ACTION"]="KILL_ORDER",
		["ORDER_KEY"]=orderkey
	}
	local res=sendTransaction(transaction)
	if res~="" then
		return false,"QL.killOrder(): "..res
	else
		return true,"QL.killOrder(): Limit order kill sended. MAY NOT KILL!!! Class="..class.." Sec="..security.." Key="..orderkey.." Trans_id="..trans_id
	end
end
function killAllOrders(table_mask)
	-- данная функция отправит транзакции на отмену АКТИВНЫХ заявок соответствующим фильтру указанному как входящий параметр table_mask
	-- список всех возможных параметров  : ACCOUNT,CLASSCODE,SECCODE,OPERATION,CLIENT_CODE,COMMENT
	-- если вызвать функцию с параметром nil - снимутся ВСЕ активные заявки
	local i,key,val,result_num=0,0,0,0
	local tokill=true
	local row={}
	local result_str=""
	for i=1,getNumberOf("orders"),1 do
		row=getItem("orders",i)
		tokill=false
		--toLog(log,"Row "..i.." onum="..row.ordernum)
		if orderflags2table(row.flags).active==1 then
			tokill=true
			--toLog(log,"acitve")
			if table_mask~=nil then
				for key,val in pairs(table_mask) do
					--toLog(log,"check key="..key.." val="..val)
					--toLog(log,"strlowe="..string.lower(key).." row="..row[string.lower(key)].." tbl="..val)
					if row[string.lower(key)]~=val then
						tokill=false
						--toLog(log,"false cond. t="..table_mask.key.." row="..row[string.lower(key)])
						break
					end
				end
			end
		end
		if tokill then
			--toLog(log,"kill onum"..row.ordernum)
			res,_=killOrder(row.class_code,row.seccode,tostring(row.ordernum))
			result_num=result_num+1
			--toLog(log,ms)
			if res then
				result_str=result_str..row.ordernum..","
			else
				result_str=result_str.."!"..row.ordernum..","
			end
		end
	end
	return true,"QL.killAllOrders(): Sended "..result_num.." transactions. Ordernums:"..result_str
end
function toLog(file_path,value)
	-- запись в лог параметра value
	-- value может быть числом, строкой или ДВУМЕРНОЙ таблицей (таблица элементом которой является таблица записана не будет!)
	-- file_path  -  путь к файлу
	-- файл открывается на дозапись и закрывается после записи строки
	if file_path~=nil and value~=nil then
		lf=io.open(file_path,"a+")
		if lf~=nil then
			if type(value)=="string" or type(value)=="number" then
				lf:write(getHRDateTime().." "..value.."\n")
			elseif type(value)=="table" then
				local k,v,str=0,0,""
				for k,v in pairs(value) do
					str=str..k.."="..v..";"
				end
				lf:write(getHRDateTime().." "..str.."\n")
			end
			lf:flush()
			lf:close()
		end
	end
end
function getHRTime()
	-- возвращает время с милисекундами в виде строки
	local now=socket.gettime()
	return string.format("%s,%3d",os.date("%X",now),select(2,math.modf(now))*1000)
end
function getHRDateTime()
	-- Возвращает строку с текущей датой и время с милисекундами
	local now=socket.gettime()
	return string.format("%s,%3d",os.date("%c",now),select(2,math.modf(now))*1000)
end
function toPrice(class,security,value)
	-- преобразования значения value к цене инструмента правильного формата
	-- Возвращает строку
	local scale=getParamEx(class,security,"SEC_SCALE").param_value
	local pos
	_,pos=string.find(tostring(value),"%d+.")
	if tonumber(scale)>0 then
		value=string.sub(value,0,pos+scale)
	else
		value=string.sub(value,0,pos-1)
	end 
	return tostring(value)
end
function getPosFromTable(table,value)
	-- Возвращает ключ значения value из таблицы table, иначе -1
	toLog("temp.txt","val="..value)
	if (table==nil or value==nil) then
		toLog("temp.txt","nil")
		return -1
	else
		local k,v
		for k,v in pairs(table) do
			toLog("temp.txt","v="..v.." val="..value)
			if v==value then
				return k
			end
		end
		return -1
	end
end
function orderflags2table(flags)
	-- фнукция возвращает таблицу с полным описанием заявки по флагам
	-- Атрибуты : active, cancelled, done,operation("B" for Buy, "S" for Sell),limit(1 - limit order, 0 - market order)
	local t={}
	if bit_set(flags, 0) then
		t.active=1
	else
		t.active = 0
	end
	if bit_set(flags,1) then
		t.cancelled=1
	elseif t.active==1 then
		t.done=1
		t.cancelled=0
	else
		t.done=0
		t.cancelled=0
	end
	if bit_set(flags, 2) then
		t.operation="S"
	else
		t.operation = "B"
	end
	if bit_set(flags, 3) then
		t.limit=1
	else
		t.limit = 0
	end
	if t.cancelled==1 and t.done==1 then
		message("Erorr in orderflags2table order cancelled and done!",2)
	end
	return t
end
function bit_set( flags, index )
	--функция возвращает true, если бит [index] установлен в 1
	local n=1
    n=bit.lshift(1, index)
    if bit.band(flags, n) ~=0 then
       return true
    else
       return false
    end
end