if string.find(package.path,'C:\\Program Files (x86)\\Lua\\5.1\\lua\\?.lua')==nil then
   package.path=package.path..';C:\\Program Files (x86)\\Lua\\5.1\\lua\\?.lua;'
end
if string.find(package.path,'C:\\Program Files\\Lua\\5.1\\lua\\?.lua')==nil then
   package.path=package.path..';C:\\Program Files\\Lua\\5.1\\lua\\?.lua;'
end 

require("QL")

log="Costs_Counter.log"

spot_comission=0,0007
fut_comission=1,85

is_run=false
trades={} -- "транспортная" таблица для сделок. С ее помощью мы будем обрабатывать данные не в коллбэке Квика а в главном потоке ВМ Луа
-- GUI
--создаем таблицу Квик
t=QTable:new()

function OnStop()
  is_run = false
  toLog(log,'OnStop. Script finished manually')
  message ("Script finished manually", 2)
end
function OnInit(path)
  log=getScriptPath()..'\\'..log
  is_run=true
end
function OnTrade(trade)
	trades[#trades+1]=trade
end

function CountandAdd(trade)
	local l,op,bc,rc=t:AddLine(),'',0,0
	t:SetValue(l,'Time',datetime2string(trade.datetime))
	t:SetValue(l,'Account',trade.account)
	t:SetValue(l,'Client_code',trade.client_code)
	t:SetValue(l,'Security',trade.sec_code)
	if tradeflags2table(trade.flags).operation=='S' then 
		op='Продажа' 
		rp=(trade.value-trade.exchange_comission-bc)/trade.qty
	else 
		rp=(trade.value+trade.exchange_comission+bc)/trade.qty
		op='Покупка' 
	end
	t:SetValue(l,'Operation',op)
	t:SetValue(l,'Deal_price',trade.price)
	t:SetValue(l,'Quantity',trade.qty)
	t:SetValue(l,'Volume',trade.value)
	t:SetValue(l,'Stock_comission',trade.exchange_comission)
	toLog(log,'Exch com='..trade.exchange_comission)
	if string.find(FUT_OPT_CLASSES,trade.class_code)~=nil then bc=trade.qty*fut_comission else bc=trade.value*spot_comission end
	t:SetValue(l,'Broker_comission',bc)
	t:SetValue(l,'Full_comission',(trade.exchange_comission+bc))
	t:SetValue(l,'Real_price',rc)
end

function main()
	--добавляем нужные столбцы: 	
	t:AddColumn("Time",QTABLE_STRING_TYPE ,20)
	t:AddColumn("Account",QTABLE_STRING_TYPE,20)
	t:AddColumn("Client_code",QTABLE_STRING_TYPE,20)
	t:AddColumn("Security",QTABLE_STRING_TYPE,20)
	t:AddColumn("Operation",QTABLE_STRING_TYPE,20)
	t:AddColumn("Deal_price",QTABLE_DOUBLE_TYPE ,20)	
	t:AddColumn("Quantity",QTABLE_DOUBLE_TYPE,20)
	t:AddColumn("Volume",QTABLE_DOUBLE_TYPE,20)
	t:AddColumn("Stock_comission",QTABLE_DOUBLE_TYPE,20)
	t:AddColumn("Broker_comission",QTABLE_DOUBLE_TYPE,20)
	t:AddColumn("Full_comission",QTABLE_DOUBLE_TYPE,20)
	t:AddColumn("Real_price",QTABLE_DOUBLE_TYPE,20)
	-- назначаем название для таблицы
	t:SetCaption('Costs_Counter')
	-- показываем таблицу
	t:Show()
	-- добавляем пустую строку
	line=t:AddLine()
		
	local i=0
	for i=0,getNumberOf('trades') do
		row=getItem('trades',i)
		CountandAdd(row)
	end
	toLog(log,"Old trades processed.")

	while is_run do
		if #trades~=0 then
			local t=table.remove(trades,1)
			if t==nil then toLog(log,"Nil trade on remove") else CountandAdd(t) end
		else 
			sleep(1)
		end
	end	
end