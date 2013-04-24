--[[Робот "Айсберг" предназначен для трейдера, который хочет мелкими пакетами купить или продать крупный объём. Робот работает по такому алгоритму:
1. Трейдер задаёт торговый инструмент и размер позиции, которую хочет иметь
2. Робот выставляет в стакан "лучшим" один лот этого инструмента и ждёт акцепта.
3. Если его обгоняют, он тоже обгоняет. Если позади него появляется пустое место, куда можно передвинуться, он передвигается. Так реализуется механизм Best Execution.
4. После акцепта робот выставляет новый лот в стакан.
5. Так продолжается до тех пор, пока текущий баланс не сравняется с желаемым балансом. 
--]]
VERSION='0.1'
require("QL")
require("iuplua")
log='Iceberg.log'

security=' '
orders={}
quotes={}
transactions={}
account=' '
order_status=''
order_price=0
class=''
clc=' '
desire_vol=0
last_run=0
delay=1
pos_acc=''
price=0
delta=0
direction=''
lot=0
--quik
function OnStop()
	is_run=false
	toLog(log,'Script Stopped')
end
function OnOrder(order)
	if is_run and order.sec_code==security then
		table.insert(orders,order)
	end
end
function OnQuote(cl,sec)
	if is_run and sec==security then
		new_quote=true
	end
end
function OnDisconnected()
	toLog(log,'Terminal disconected')
	is_run=false
end
-- func
function OnOrderDo(order)
end
function OnQuoteDo()
	local q=getQuoteLevel2(class,security)
	local bb=q.bid[tonumber(q.bid_count)].price
	local ba=q.offer[1].price
	local sb=q.bid[tonumber(q.bid_count)-1].price
	local sa=q.offer[2].price
	local bbv=q.bid[tonumber(q.bid_count)].quantity
	local bav=q.offer[1].quantity
	delta=math.abs(desired_pos-getPosition(security,pos_acc))
	if order_status=='active' then
	elseif delta>0 then
		
	else
		toLog(log,'Position openned. Stop Iceberg')
		is_run=false
	end
end
function OnInitDo()
	toLog(log,'start initialization...')
	ret, security, account,clc, desire_vol, price, lot_size=
      iup.GetParam("Begemot "..VERSION, nil,
                  "Код бумаги: %s\n"..
				  "Счет: %s\n"..
				  "Код клиента: %s\n"..
				  "Объем: %i\n"..
				  "Гpаничная цена: %r\n"..
				  "Размер заявки(в мин. лотах): %i\n",
				  security, account,clc, desire_vol, price)
	toLog(log,"GetSettingsParam done")
	if (not ret) then
		iup.Message("Iceberg "..VERSION,"Запуск скрипта отменен.")
		toLog(log,"Cancelled on GetSettingsParam")
		return false
	end
	class=getClass(security)
	lot=getParam(security,'lotsize')*lot_size
	if string.find(FUT_OPT_CLASSES,class)~+nil then pos_acc=account else pos_acc=clc end
	return true
end
function main()
	is_run=OnInitDo()
	toLog(log,"Main started")
	pos=getPosition(security,pos_acc)
	delta=desired_pos-pos
	if delta>0 then 
		direction='B'
		delta=math.abs(delta)
		OnQuoteDo()
	elseif delta<0 then 
		direction='S'
		delta=math.abs(delta)
		OnQuoteDo()
	else is_run=false toLog(log,'Current position('..pos..') equal to desired pos('..desired_pos..')')
	end
	while is_run do
		if #orders~=0 then
			local t=table.remove(orders,1)
			if t~=nil then OnOrderDo(t) else toLog(log,'Nil order on remove') end
		elseif new_quote then
			new_quote=false
			OnQuoteDo()
		else
			sleep(10)
		end
	end
	toLog(log,'Main ended')
	iup.ExitLoop()
	iup.Close()
end