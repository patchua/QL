-- Version 0.3
--[[
	Добавили moveOrder,moveOrderSpot,moveOrderFO. Вынесли список срочных классов - FUT_OPT_CLASSES. Изменили порядок входящих параметров killOrder и необходимое их минимальное количество.
	Изменили количество входных параметров в toPrice. Добавили функцию getRowFromTable. Изменили исходящие пароаметры sendLimit, sendMarket, sendRPS, sendReportOnRPS
]]--
package.cpath=".\\?.dll;.\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\?.dll;C:\\Program Files (x86)\\Lua\\5.1\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\?.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\loadall.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\loadall.dll;C:\\Program Files\\Lua\\5.1\\?.dll;C:\\Program Files\\Lua\\5.1\\?51.dll;C:\\Program Files\\Lua\\5.1\\clibs\\?.dll;C:\\Program Files\\Lua\\5.1\\clibs\\?51.dll;C:\\Program Files\\Lua\\5.1\\loadall.dll;C:\\Program Files\\Lua\\5.1\\clibs\\loadall.dll"..package.cpath
package.path=package.path..";.\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?\\init.lua;C:\\Program Files (x86)\\Lua\\5.1\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\?\\init.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?.luac;C:\\Program Files\\Lua\\5.1\\lua\\?.lua;C:\\Program Files\\Lua\\5.1\\lua\\?\\init.lua;C:\\Program Files\\Lua\\5.1\\?.lua;C:\\Program Files\\Lua\\5.1\\?\\init.lua;C:\\Program Files\\Lua\\5.1\\lua\\?.luac;"
require"bit"
require"socket"
FUT_OPT_CLASSES="FUTUX,OPTUX,SPBOPT,SPBFUT"
--require"iuplua"
--require"iupluacontrols"
--[[
Trading Module
]]--
function sendLimit(class,security,direction,price,volume,account,client_code,comment)
	-- отправка лимитированной заявки
	-- все параметры кроме кода клиента и коментария должны быть не нил
	-- ВАЖНО! цена должна быть стрингом с количеством знаков после точки для данной бумаги
	-- если код клиента нил - подлставляем счет
	-- Данная функция возвращает 2 параметра 
	--     1. ID присвоенный транзакции либо nil если транзакция отвергнута на уровне сервера Квик
	--     2. Ответное сообщение сервера Квик либо строку с параметрами транзакции
	if (class==nil or security==nil or direction==nil or price==nil or volume==nil or account==nil) then
		return nil,"QL.sendLimit(): Can`t send order. Nil parameters."
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
		return nil, "QL.sendLimit():"..res
	else
		return trans_id, "QL.sendLimit(): Limit order sended sucesfully. Class="..class.." Sec="..security.." Dir="..direction.." Price="..price.." Vol="..volume.." Acc="..account.." Trans_id="..trans_id
	end
end
function sendMarket(class,security,direction,volume,account,client_code,comment)
	-- отправка рыночной заявки
	-- все параметры кроме кода клиента и коментария должны быть не нил
	-- если код клиента нил - подлставляем счет
	-- Данная функция возвращает 2 параметра 
	--     1. ID присвоенный транзакции либо nil если транзакция отвергнута на уровне сервера Квик
	--     2. Ответное сообщение сервера Квик либо строку с параметрами транзакции
	if (class==nil or security==nil or direction==nil  or volume==nil or account==nil) then
		return nil,"QL.sendMarket(): Can`t send order. Nil parameters."
	end
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
		return nil, "QL.sendMarket():"..res
	else
		return trans_id, "QL.sendMarket(): Market order sended sucesfully. Class="..class.." Sec="..security.." Dir="..direction.." Vol="..volume.." Acc="..account.." Trans_id="..trans_id
	end
end
function moveOrder(mode,fo_number,fo_p,fo_q,so_number,so_p,so_q)
	-- перемещение заявки
	-- минимальный набор параметров mode,fo_number,fo_p
	-- в зависимости от класса первой заявки будет вызвана функция перемещения либо для СПОТ либо Срочного рынка
	if (fo_number==nil or fo_p==nil or mode==nil) then
		return nil,"QL.moveOrder(): Can`t move order. Nil parameters."
	end
	local forder=getRowFromTable("orders","ordernum",fo_number)
	if forder==nil then
		return nil,"QL.moveOrder(): Can`t find ordernumber="..fo_number.." in orders table!"
	end
	if string.find(FUT_OPT_CLASSES,forder.class_code)~=nil then
		return moveOrderFO(mode,fo_number,fo_p,fo_q,so_number,so_p,so_q)
	else
		return moveOrderSpot(mode,fo_number,fo_p,fo_q,so_number,so_p,so_q)
	end
end
function moveOrderSpot(mode,fo_number,fo_p,fo_q,so_number,so_p,so_q)
	-- перемещение заявок для рынка спот
	-- минимальный набор параметров mode,fo_number,fo_p
	-- отправится 2 транзакции снятие+постановка для каждой из указанных заявок
	-- Возвращаем 2 параметра :
	-- 1. Nil - если неудача или номер транзакции (2-й если 2 заявки)
	-- 2. Диагностиеское сообщение
	if (order_number==nil or new_price==nil or regim==nil) then
		return nil,"QL.moveOrderSpot(): Can`t move order. Nil parameters."
	end
	local forder=getRowFromTable("orders","ordernum",fo_number)
	if forder==nil then
		return nil,"QL.moveOrderFO(): Can`t find ordernumber="..fo_number.." in orders table!"
	end
	if (orderflags2table(forder.flags).cancelled==1 or (orderflags2table(forder.flags).done==1 and forder.balance==0)) then
		return nil,"QL.moveOrderSpot(): Can`t move cancelled or done order!"
	end
	if mode==0 then
		--Если MODE=0, то заявки с номерами, указанными после ключей FIRST_ORDER_NUMBER и SECOND_ORDER_NUMBER, снимаются. 
		--В торговую систему отправляются две новые заявки, при этом изменяется только цена заявок, количество остается прежним;
		if so_number~=nil and so_p~=nil then
			_,_=killOrder(fo_number,forder.seccode,forder.class_code)
			trid,ms1=sendLimit(forder.class_code,forder.seccode,orderflags2table(forder.flags).operation,fo_p,forder.qty,forder.account,forder.client_code,forder.comment)
			local sorder=getRowFromTable("orders","ordernum",so_number)
			if sorder==nil then
				return nil,"QL.moveOrderFO(): Can`t find ordernumber="..so_number.." in orders table!"
			end
			_,_=killOrder(so_number,sorder.seccode,sorder.class_code)
			trid2,ms2=sendLimit(sorder.class_code,sorder.seccode,orderflags2table(sorder.flags).operation,so_p,sorder.qty,sorder.account,sorder.client_code,sorder.comment)
			if trid~=nil and trid2~=nil then
				return trid2,"QL.moveOrderSpot(): Orders moved. Trans_id1="..trid.." Trans_id2="..trid2
			else
				return nil,"QL.moveOrderSpot(): One or more orders not moved! Msg1="..ms1.." Msg2="..ms2
			end
		else
			_,_=killOrder(fo_number,forder.seccode,forder.class_code)
			local trid,ms=sendLimit(forder.class_code,forder.seccode,orderflags2table(forder.flags).operation,fo_p,forder.qty,forder.account,forder.client_code,forder.comment)
			if trid~=nil then
				return trid,"QL.moveOrderSpot(): Order moved. Trans_Id="..trid
			else
				return nil,"QL.moveOrderSpot(): Order not moved! Msg="..ms
			end
		end
	elseif mode==1 then
		--Если MODE=1, то заявки с номерами, указанными после ключей FIRST_ORDER_NUMBER и SECOND_ORDER_NUMBER, снимаются. 
		--В торговую систему отправляются две новые заявки, при этом изменится как цена заявки, так и количество;
		if so_number~=nil and so_p~=nil and so_q~=nil then
			_,_=killOrder(fo_number,forder.seccode,forder.class_code)
			local trid,ms1=sendLimit(forder.class_code,forder.seccode,orderflags2table(forder.flags).operation,fo_p,fo_q,forder.account,forder.client_code,forder.comment)
			local sorder=getRowFromTable("orders","ordernum",so_number)
			if sorder==nil then
				return nil,"QL.moveOrderFO(): Can`t find ordernumber="..so_number.." in orders table!"
			end
			_,_=killOrder(so_number,sorder.seccode,sorder.class_code)
			local trid2,ms2=sendLimit(sorder.class_code,sorder.seccode,orderflags2table(sorder.flags).operation,so_p,so_q,sorder.account,sorder.client_code,sorder.comment)
			if trid~=nil and trid2~=nil then
				return trid2,"QL.moveOrderSpot(): Orders moved. Trans_id1="..trid.." Trans_id2="..trid2
			else
				return nil,"QL.moveOrderSpot(): One or more orders not moved! Msg1="..ms1.." Msg2="..ms2
			end
		else
			_,_=killOrder(fo_number,forder.seccode,forder.class_code)
			local trid,ms=sendLimit(forder.class_code,forder.seccode,orderflags2table(forder.flags).operation,fo_p,fo_q,forder.account,forder.client_code,forder.comment)
			if trid~=nil then
				return trid,"QL.moveOrderSpot(): Order moved. Trans_Id="..trid
			else
				return nil,"QL.moveOrderSpot(): Order not moved! Msg="..ms
			end
		end
	elseif mode==2 then
		--Если MODE=2,  то заявки с номерами, указанными после ключей FIRST_ORDER_NUMBER и SECOND_ORDER_NUMBER, снимаются. 
		--Если количество бумаг в каждой из снятых заявок совпадает со значениями, указанными после FIRST_ORDER_NEW_QUANTITY и SECOND_ORDER_NEW_QUANTITY, то в торговую систему отправляются две новые заявки с соответствующими параметрами.
		if so_number~=nil and so_p~=nil and so_q~=nil then
			local sorder=getRowFromTable("orders","ordernum",so_number)
			if sorder==nil then
				return nil,"QL.moveOrderFO(): Can`t find ordernumber="..so_number.." in orders table!"
			end
			_,_=killOrder(fo_number,forder.seccode,forder.class_code)
			_,_=killOrder(so_number,sorder.seccode,sorder.class_code)
			if forder.balance==fo_q and sorder.balance==so_q then
				local trid,ms1=sendLimit(forder.class_code,forder.seccode,orderflags2table(forder.flags).operation,fo_p,fo_q,forder.account,forder.client_code,forder.comment)
				local trid2,ms2=sendLimit(sorder.class_code,sorder.seccode,orderflags2table(sorder.flags).operation,so_p,so_q,sorder.account,sorder.client_code,sorder.comment)
				if trid~=nil and trid2~=nil then
					return trid2,"QL.moveOrderSpot(): Orders moved. Trans_id1="..trid.." Trans_id2="..trid2
				else
					return nil,"QL.moveOrderSpot(): One or more orders not moved! Msg1="..ms1.." Msg2="..ms2
				end
			else
				return nil,"QL.moveOrderSpot(): Mode=2. Orders balance~=new_quantity"
			end
		else
			_,_=killOrder(fo_number,forder.seccode,forder.class_code)
			local trid,ms=sendLimit(forder.class_code,forder.seccode,orderflags2table(forder.flags).operation,fo_p,fo_q,forder.account,forder.client_code,forder.comment)
			if trid~=nil then
				return trid,"QL.moveOrderSpot(): Order moved. Trans_Id="..trid
			else
				return nil,"QL.moveOrderSpot(): Order not moved! Msg="..ms
			end
		end
	else
		return nil,"QL.moveOrder(): Mode out of range! Mode can be from {0,1,2}"
	end
end
function moveOrderFO(mode,fo_number,fo_p,fo_q,so_number,so_p,so_q)
	-- перемещение заявок для срочного рынка
	-- отправка "нормальной" транзакции Квика
	if (fo_number==nil or fo_p==nil or mode==nil) then
		return nil,"QL.moveOrderFO(): Can`t move order. Nil parameters."
	end
	local transaction={}
	if mode==0 then
		if so_number~=nil and so_p~=nil then
			transaction["SECOND_ORDER_NUMBER"]=tostring(so_number)
			transaction["SECOND_ORDER_NEW_PRICE"]=so_p
			transaction["SECOND_ORDER_NEW_QUANTITY"]="0"
		end
		transaction["FIRST_ORDER_NUMBER"]=tostring(fo_number)
		transaction["FIRST_ORDER_NEW_PRICE"]=fo_p
		transaction["FIRST_ORDER_NEW_QUANTITY"]="0"
	elseif mode==1 then
		if fo_q==nil or fo_q==0 then
			return nil,"QL.moveOrder(): Mode=1. First Order Quantity can`t be nil or zero!"
		end
		if so_number~=nil and so_p~=nil and so_q>0 then
			transaction["SECOND_ORDER_NUMBER"]=tostring(so_number)
			transaction["SECOND_ORDER_NEW_PRICE"]=so_p
			transaction["SECOND_ORDER_NEW_QUANTITY"]=tostring(so_q)
		end
		transaction["FIRST_ORDER_NUMBER"]=tostring(fo_number)
		transaction["FIRST_ORDER_NEW_PRICE"]=fo_p
		transaction["FIRST_ORDER_NEW_QUANTITY"]=tostring(fo_q)
	elseif mode==2 then
		if fo_q==nil or fo_q==0 then
			return nil,"QL.moveOrder(): Mode=2. First Order Quantity can`t be nil or zero!"
		end
		if so_number~=nil and so_p~=nil and so_q>0 then
			transaction["SECOND_ORDER_NUMBER"]=tostring(so_number)
			transaction["SECOND_ORDER_NEW_PRICE"]=so_p
			transaction["SECOND_ORDER_NEW_QUANTITY"]=tostring(so_q)
		end
		transaction["FIRST_ORDER_NUMBER"]=tostring(fo_number)
		transaction["FIRST_ORDER_NEW_PRICE"]=fo_p
		transaction["FIRST_ORDER_NEW_QUANTITY"]=tostring(fo_q)
	else
		return nil,"QL.moveOrder(): Mode out of range! mode can be from {0,1,2}"
	end
	local trans_id=math.random(2000000000)
	local order=getRowFromTable("orders","ordernum",fo_number)
	if order==nil then
		return nil,"QL.moveOrderFO(): Can`t find ordernumber="..fo_number.." in orders table!"
	end
	local transaction={
		["TRANS_ID"]=tostring(trans_id),
		["CLASSCODE"]=order.class_code,
		["SECCODE"]=order.seccode,
		["ACTION"]="MOVE_ORDERS"
	}
	local res=sendTransaction(transaction)
	if res~="" then
		return nil, "QL.moveOrderFO():"..res
	else
		return trans_id, "QL.moveOrderFO(): Market order sended sucesfully. Mode="..mode.." FONumber="..fo_number.." FOPrice="..fo_p
	end
end
function sendRPS(class,security,direction,price,volume,account,client_code,partner)
    -- функция отправки заявки на внебиржевую сделку
	if (class==nil or security==nil or direction==nil or price==nil or volume==nil or account==nil or partner==nil) then
		return nil,"QL.sendRPS(): Can`t send order. Nil parameters."
	end
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
		return nil, "QL.sendRPS():"..res
	else
		return trans_id, "QL.sendRPS(): RPS order sended sucesfully. Class="..class.." Sec="..security.." Dir="..direction.." Price="..price.." Vol="..volume.." Acc="..account.." Partner="..partner.." Trans_id="..trans_id
	end
end
function sendReportOnRPS(class,operation,key)
    -- отправка отчета по сделки для исполнения
	if(class==nil or operation==nil or key==nil) then
		return nil,"QL.sendRPS(): Can`t send order. Nil parameters."
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
		return nil, "QL.sendReportOnRPS():"..res
	else
		return trans_id, "QL.sendReportOnRPS(): ReportOnRPS order sended sucesfully. Class="..class.." Oper="..operation.." Key="..key.." Trans_id="..trans_id
	end
end
function killOrder(orderkey,security,class)
	-- функция отмены лимитированной заявки по номеру
	-- принимает минимум 1 парамер
	-- ВАЖНО! Данная функция не гарантирует снятие заявки
	-- Возвращает сообщение сервера в случае ошибки выявленной сервером Квик либо строку с информацией о транзакции
	if orderkey==nil or tonumber(orderkey)==0 then
		return nil,"QL.killOrder(): Can`t kill order. OrderKey nil or zero"
	end
	local trans_id=math.random(2000000000)
	local transaction={
		["TRANS_ID"]=tostring(trans_id),
		["SECCODE"]=security,
		["ACTION"]="KILL_ORDER",
		["ORDER_KEY"]=tostring(orderkey)
	}
	if (security==nil and class==nil) or (class~=nil and security==nil) then
		local order=getRowFromTable("orders","ordernum",orderkey)
		transaction.class_code=order.class_code
		transaction.seccode=order.seccode
	elseif	security~=nil then
		transaction.seccode=security
		transaction.class_code=getSecurityInfo("",security).class_code
	else
		transaction.seccode=security
		transaction.class_code=class 
	end
	local res=sendTransaction(transaction)
	if res~="" then
		return nil,"QL.killOrder(): "..res
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
--[[
Support Functions
]]--
function toLog(file_path,value)
	-- запись в лог параметра value
	-- value может быть числом, строкой или таблицей 
	-- file_path  -  путь к файлу
	-- файл открывается на дозапись и закрывается после записи строки
	if file_path~=nil and value~=nil then
		lf=io.open(file_path,"a+")
		if lf~=nil then
			if type(value)=="string" or type(value)=="number" then
				lf:write(getHRDateTime().." "..value.."\n")
			elseif type(value)=="table" then
				lf:write(getHRDateTime().." "..table2string(value).."\n")
			end
			lf:flush()
			lf:close()
		end
	end
end
function table2string(table)
	local k,v,str=0,0,""
	for k,v in pairs(table) do
		if type(v)=="string" or type(v)=="number" then
			str=str..k.."="..v
		elseif type(v)=="table"then
			str=str..k.."={"..table2string(v).."}"
		elseif type(v)=="function" then
			str=str..tostring(v)
		end
	end
	return str
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
function toPrice(security,value)
	-- преобразования значения value к цене инструмента правильного ФОРМАТА (обрезаем лишнии знаки после разделителя)
	-- Возвращает строку
	local scale=getParamEx(getSecurityInfo("",security).class_code,security,"SEC_SCALE").param_value
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
	if (table==nil or value==nil) then
		return -1
	else
		local k,v
		for k,v in pairs(table) do
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
function getRowFromTable(table_name,key,value)
	-- возвращаем строку (таблицу Луа) из таблицы table_name с столбцом key равным value.
	-- table_name[key].value
	local i
	for i=getNumberOf(table_name),0,-1 do
		if getItem(table_name,i)[key]==value then
			return getItem(table_name,i)
		end
	end
	return nil
end