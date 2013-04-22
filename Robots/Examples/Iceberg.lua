--[[Робот "Айсберг" предназначен для трейдера, который хочет мелкими пакетами купить или продать крупный объём. Робот работает по такому алгоритму:
1. Трейдер задаёт торговый инструмент и размер позиции, которую хочет иметь
2. Робот выставляет в стакан "лучшим" один лот этого инструмента и ждёт акцепта.
3. Если его обгоняют, он тоже обгоняет. Если позади него появляется пустое место, куда можно передвинуться, он передвигается. Так реализуется механизм Best Execution.
4. После акцепта робот выставляет новый лот в стакан.
5. Так продолжается до тех пор, пока текущий баланс не сравняется с желаемым балансом. 
--]]

require("QL")
require("iuplua")

--Вводим номер торгового счёта
account="101083"

--Вводим код клиента
client_code="101083/01"

--К заявкам будем дописывать код "Iceberg"
comment="Iceberg"

--Вводим торговый инструмент
_, security = iup.GetParam("Торговый инструмент", nil, "Введите код бумаги: %s\n","")

class=getSecurityInfo("",security).class_code

--Получаем размер лота
lot=getParamEx(class,security,"lotsize").param_value
	
--Получаем шаг цены
step=getParamEx(class,security,"SEC_PRICE_STEP").param_value
toLog(log, "step="..step)

--[[Выбираем, размер позиции в штуках акций (контрактов), который хотим иметь. Если нужно, чтобы робот Айсберг закрыл позицию, пишем 0. 
Пример 1. На балансе 0 акций GAZP. Хотим, чтобы робот набрал позицию в размере 10 000 акций. Значит пишем 10 000. 
Пример 2. На балансе 0 контрактов на фьючерс РТС . Хотим чтобы робот зашортил 500 контрактов. Значит пишем -500.
Пример 2. На балансе 100 000 акций ALMK. Хотим, чтобы робот закрыл эту позицию в ноль. Значит пишем 0.
Пример 3. На балансе шорт -100 акций LKOH. Хотим чтобы робот откупил этот шорт и набрал лонг 50 акций. Значит пишем 0.
--]]

_, final_balance=iup.GetParam("Итоговый баланс", nil, "Сколько акций (контрактов) должно стать: %s\n","")
final_balance=tonumber(final_balance) --Юра, не знаю надо ли тут переводить в числовой формат.

is_run = true

--Блок функций

function order_inspector(security, proper_price)

--true если хорошая заявка есть
--false если хорошей заявки нет. В том числе false если мы попутно удаляли плохую заявку.
--функция принимает бумагу и надлежащую цену. 

local line
	for i=getNumberOf("orders"),0,-1 do
		line=getItem("orders",i)
			if line.seccode==security and line.account==account and line.balance>0 then
				if line.price==proper_price then
					return true 
				else
					order_number=line.ordernum
					killOrder=(order_number)
				end
				return false
			end
	end
	return false
end

function is_it_my_quote(price_from_glass, volume_from_glass, security, account)
   local row
   for i=getNumberOf("orders"),0,-1 do
      row=getItem("orders",i)
      if row.seccode==security and row.account==account and row.balance>0 and row.price==price_from_glass then
         if row.balance==volume_from_glass then
            return true,true
         else
            return true,false
         end
         break
      end
   end
   return false,false
end

function OnStop()
  is_run = false
  toLog(log,'OnStop. Script finished manually')
  message ("Скрипт остановлен вручную", 2)
  -- уничтожаем таблицу Квик
end

function main()

	balance=getPosition(security,account)
	if final_balance>balance then
		mode="BUY MODE"
	elseif final_balance<balance then
		mode="SELL MODE"
	else
		mode="WE HAPPY"
		iup.Message('Финиш','Работа сделана. У Вас '..balance.." "..security)
	end

	--Получаем стакан. Берём первых и вторых лучших.
	
	local qt = getQuoteLevel2(class, security)
	local bid_1 = security, qt.bid[tonumber(qt.bid_count)].price
	local bid_1_q = security, qt.bid[tonumber(qt.bid_count)].quantity
	local offer_1 = security, qt.offer[1].price
	local offer_1_q = security, qt.offer[1].quantity
	local bid_2 = security, qt.bid[tonumber(qt.bid_count)-1].price
	local offer_2 = security, qt.offer[2].price

	if mode=="BUY MODE" then	

		--Мы должны быть лучшими на бидах. Проверяем так ли это.
		am_i_best_bid, am_i_unique_best_bid=is_it_my_quote(bid_1, bid_1_q, security, account)

				--если я лучший бид и со мной больше никто не стоит, то надлежащая цена - второй бид + шаг цены
			if am_i_best_bid and am_i_unique_best_bid then 
				proper_price=bid_2+step
	
				--если я лучший бид, и со мной по этой же цене кто то стоит, то надлежащая цена - та по которой я стою, то есть лучший бид. Сосед мне не помеха, первым акцептуют меня.
			elseif am_i_best_bid and not am_i_unique_best_bid then
				proper_price=bid_1

				--если я не лучший бид, то надлежащая цена - лучший бид+шаг цены
			else
				proper_price=bid_1+step
			end

		good_bid=order_inspector(sec, proper_price)

			if not good_bid then
				send_limit_buy, reply=sendLimit(class,security,"B",proper_price,lot,account,client_code,comment)
				toLog (log, reply)
			end
	elseif mode=="SELL MODE" then
				--Мы должны быть лучшими на асках. Проверяем так ли это.
		am_i_best_ask, am_i_unique_best_ask=is_it_my_quote(offer_1, offer_1_q, security, account)

				--если я лучший аск и со мной больше никто не стоит, то надлежащая цена - второй аск - шаг цены
			if am_i_best_ask and am_i_unique_best_ask then 
				proper_price=offer_2-step
	
				--если я лучший аск, и со мной по этой же цене кто то стоит, то надлежащая цена - та по которой я стою, то есть лучший аск. Сосед мне не помеха, первым акцептуют меня.
			elseif am_i_best_ask  and not am_i_unique_best_ask then
				proper_price=offer_1

				--если я не лучший аск, то надлежащая цена - лучший аск-шаг цены
			else
				proper_price=offer_1-step
			end

		good_ask=order_inspector(sec, proper_price)

			if not good_ask then
				send_limit_sell, reply=sendLimit(class,security,"S",proper_price,lot,account,client_code,comment)
				toLog (log, reply)
			end
	sleep(1000) - засыпаем на 1 секунду
	end
	
end