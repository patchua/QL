-- version 0.4.0
-- bug FIXed in TradeBid, TradeOffer, FindBidClosePrice
-- 0.3 transaction sync mechanizm
-- 0.3.1 reduce exess transactions
-- 0.3.2 bug in change orders on update
-- 0.4 different versions for spot and fut, moved from OnAllTrade to OnParam, no class in settings
require"QL"
require"luaxml"
log="begemot.log"
settings_file="settings.xml"
watch_list={}
transactions={}
quotes={}
orders={}
all_trades={}
on_param={}
trans_replies={}
bad_transactions={}
is_run=false
last_trade=0

function getSettings(path)
	toLog(log,"Try to open settings "..path)
	local file=xml.load(path)
	toLog(log,"XML loaded")
	if file==nil then
		message("Begemot can`t open settings file!",3)
		toLog(log,"File can`t be openned!")
		return false
	end 
	toLog(log,"File oppened")
	watch_list.code=file:find("security").value
	watch_list.class=getSecurityInfo('',watch_list.code).class_code
	watch_list.volume_offer=tonumber(file:find("volume_offer").value)
	watch_list.volume_bid=tonumber(file:find("volume_bid").value)
	watch_list.tp=tonumber(file:find("takeprofit").value)
	watch_list.volume=tonumber(file:find("volume").value)
	watch_list.account=file:find("account").value
	watch_list.client_code=file:find("clc").value
	watch_list.bidEnable=tonumber(file:find("bidEnable").value)
	watch_list.offerEnable=tonumber(file:find("askEnable").value)
	watch_list.position_bid=0
	watch_list.position_offer=0
	watch_list.status_bid=""
	watch_list.status_offer=""
	watch_list.order_bid={}
	watch_list.trans_bid=0
	watch_list.trans_offer=0
	watch_list.order_offer={}
	watch_list.open_price_offer=0
	watch_list.open_price_bid=0
	watch_list.minstep=getParamEx(watch_list.class,watch_list.code,"SEC_PRICE_STEP").param_value
	toLog(log,"Settings loaded")
	toLog(log,watch_list)
	return true
end
function findBegemot(type,table,count,sec)
	local i
	--local st=os.clock()
	--toLog(log,"findBegemot started type="..type.." sec="..sec.." count="..count)
	if type=="bid" then
		for i=0,count-1,1 do
			--toLog(log,"Bid "..(count-i).." vol="..table[count-i].quantity.." price="..table[count-i].price)
			if tonumber(table[count-i].quantity)>=watch_list.volume_bid then
				--toLog(log,"beg found ="..table[count-i].price.." wtch_vol="..watch_list[sec].volume_bid)
				return tonumber(table[count-i].price)
			end
		end
		return 0
	else
		for i=1,count,1 do
			--toLog(log,"Offer "..i.." vol="..table[i].quantity.." price="..table[i].price)
			if tonumber(table[i].quantity)>=watch_list.volume_offer then
				--toLog(log,"beg found ="..table[i].price.." wtch_vol="..watch_list[sec].volume_offer)
				return tonumber(table[i].price)
			end
		end
		return 0
	end
	--toLog(log,"findBegemot ended. "..(os.clock()-st))
end
function AnalyzeBegemot(sec_code,old_value,new_value)
	if old_value==0 and new_value>0 then
		toLog(log,"Begemot found! sec="..sec_code.." Price="..new_value)
		return new_value
	elseif old_value~=0 and new_value==0 then
		toLog(log,"Begemot escaped! sec="..sec_code)
		return 0
	elseif new_value~=0 and old_value~=0 and old_value~=new_value then
		toLog(log,"Begemot moved! sec="..sec_code.." old_price="..watch_list[sec_code].position_bid.." new_price="..new_value)
		return new_value
	else
		return old_value
	end
end
function TradeBid(cur_begbid,new_begbid,new_begoffer,boffer,soffer,code)
	toLog(log,"Trade BId started. CBBid="..cur_begbid.." NBBid="..new_begbid.." NBOffer="..new_begoffer.." BOffer="..soffer.." Sec="..code)
	-- если бегемот исчез и есть заявка на открытие - снять
	if watch_list.status_bid=="open" and new_begbid==0 then
		toLog(log,"Bid. если бегемот исчез и есть заявка на открытие - снять ")
		local trid,ms=killOrder(watch_list.order_bid.ordernum,code,watch_list.class)
		if trid~=nil then transactions[trid]="bid" watch_list.status_bid="wait" end
		toLog(log,ms)
	-- если бегемот появился и "условия"- выставить заявку
	elseif new_begbid~=0 and watch_list.status_bid=="" and (new_begoffer==0 or new_begoffer>new_begbid+(1+watch_list.tp)*watch_list.minstep) then
		toLog(log,"BId. если бегемот появился и условия- выставить заявку")
		local trid,ms=sendLimit(watch_list.class,code,"B",toPrice(code,new_begbid+watch_list.minstep),watch_list.volume,watch_list.account,watch_list.client_code,"BegemotOB")
		if trid~=nil then	transactions[trid]="bid" watch_list.status_bid="waitopen" watch_list.trans_bid=trid end
		toLog(log,ms)
	-- если бегемот передвинулся - передвинуть заявку
	elseif new_begbid~=0 and cur_begbid~=0 and cur_begbid~=new_begbid and watch_list.status_bid=="open" then
		toLog(log,"Bid. если бегемот передвинулся - передвинуть заявку. num="..watch_list.order_bid.ordernum.." pr="..toPrice(code,new_begbid+watch_list.minstep))
		--local trid,ms=moveOrder(0,watch_list.order_bid.ordernum,toPrice(sec_code,new_begbid+watch_list.minstep))
		local trid,ms=killOrder(watch_list.order_bid.ordernum,code,watch_list.class)
		if trid~=nil then transactions[trid]="bid" watch_list.status_bid="waitcancell" end
		toLog(log,ms)
	-- если стоим на закрытие и ниже повился бегемот - передвигаемся под него
	elseif watch_list.status_bid=="close" and new_begoffer<watch_list.order_bid.price and new_begoffer~=0 then
		toLog(log,"BId. если стоим на закрытие и ниже повился бегемот - передвигаемся под него")
		--local trid,ms=moveOrder(0,watch_list.order_bid.ordernum,toPrice(sec_code,new_begoffer-watch_list.minstep))
		local trid,ms=killOrder(watch_list.order_bid.ordernum,code,watch_list.class)
		if trid~=nil then transactions[trid]="bid" watch_list.status_bid="waitcancellclose" end
		toLog(log,ms)
	-- если стоим на закрытие и бегемота нет и можно "улучшить" место оставаясь лучшим офером - передвигаемся 
	elseif watch_list.status_bid=="close" and watch_list.order_bid.price<soffer-watch_list.minstep then
		toLog(log,"Bid. если стоим на закрытие и бегемота нет и можно улучшить место оставаясь лучшим офером - передвигаемся ")
		--trid,ms=moveOrder(0,watch_list.order_bid.ordernum,toPrice(sec_code,soffer-watch_list.minstep))
		local trid,ms=killOrder(watch_list.order_bid.ordernum,code,watch_list.class)
		if trid~=nil then transactions[trid]="bid" watch_list.status_bid="waitcancellclose" end
		toLog(log,ms)
	elseif watch_list.status_bid=="close" and boffer<watch_list.order_bid.price and watch_list.order_bid.price-watch_list.open_price_bid>=(watch_list.tp+1)*watch_list.minstep then
		toLog(log,"Bid. Стоим на закрытие на уровне лучше чем тейк-профит и перед нами появилась заявка - передвигаемся")
		toLog(log,"Status="..watch_list.status_bid.." OrderPrice="..watch_list.order_bid.price.." OpenPrice="..watch_list.open_price_bid.." TP="..watch_list.tp)
		local trid,ms=killOrder(watch_list.order_bid.ordernum,code,watch_list.class)
		if trid~=nil then transactions[trid]="bid" watch_list.status_bid="waitcancellclose" end
		toLog(log,ms)
	end
	--toLog(log,"TradeBid ended. "..(os.clock()-st))
end
function TradeOffer(cur_begoffer,new_begoffer,new_begbid,bbid,sbid,code)
	--local st=os.clock()
	toLog(log,"Trade Offer started. CBOffer="..cur_begoffer.." NBOffer="..new_begoffer.." NBBid="..new_begbid.." BBid="..bbid.." SBid="..sbid.." Sec="..code)
	-- если бегемот исчез и есть заявка на открытие - снять
	if watch_list.status_offer=="open" and new_begoffer==0 then
		toLog(log,"Offer. если бегемот исчез и есть заявка на открытие - снять ")
		local trid,ms=killOrder(watch_list.order_offer.ordernum,code,watch_list.class)
		if trid~=nil then transactions[trid]="offer" watch_list.status_offer="wait" end
		toLog(log,ms)
	-- если бегемот появился и "условия"- выставить заявку
	elseif new_begoffer~=0 and watch_list.status_offer=="" and (new_begbid==0 or new_begbid<new_begoffer-(1+watch_list.tp)*watch_list.minstep) then
		toLog(log,"Offer. если бегемот появился и условия- выставить заявку")
		local trid,ms=sendLimit(watch_list.class,code,"S",toPrice(code,new_begoffer-watch_list.minstep),watch_list.volume,watch_list.account,watch_list.client_code,"BegemotOO")
		if trid~=nil then transactions[trid]="offer" watch_list.status_offer="waitopen" watch_list.trans_offer=trid end
		toLog(log,ms)
	-- если бегемот передвинулся - передвинуть заявку
	elseif new_begoffer~=0 and cur_begoffer~=0 and cur_begoffer~=new_begoffer and watch_list.status_offer=="open" then
		toLog(log,"Offer. если бегемот передвинулся - передвинуть заявку. num="..watch_list.order_offer.ordernum.." pr="..toPrice(code,new_begoffer-watch_list.minstep))
		--local trid,ms=moveOrder(0,watch_list.order_offer.ordernum,toPrice(code,new_begoffer-watch_list.minstep))
		local tris,ms=killOrder(watch_list.order_offer.ordernum,code,watch_list.class)
		if trid~=nil then transactions[trid]="offer" watch_list.status_offer="waitcancell" end
		toLog(log,ms)
	-- если стоим на закрытие и ниже повился бегемот - передвигаемся под него
	elseif watch_list.status_offer=="close" and new_begbid>watch_list.order_offer.price and new_begbid~=0 then
		toLog(log,"Offer. если стоим на закрытие и ниже повился бегемот - передвигаемся под него")
		--local trid,ms=moveOrder(0,watch_list.order_offer.ordernum,toPrice(code,new_begbid+watch_list.minstep))
		local trid,ms=killOrder(watch_list.order_offer.ordernum,code,watch_list.class)
		if trid~=nil then transactions[trid]="offer" watch_list.status_offer="waitcancellclose" end
		toLog(log,ms)
	-- если стоим на закрытие и можно "улучшить" место оставаясь лучшим офером - передвигаемся 
	elseif watch_list.status_offer=="close" and watch_list.order_offer.price>sbid+watch_list.minstep then
		toLog(log,"Offer. если стоим на закрытие и бегемота нет и можно улучшить место оставаясь лучшим офером - передвигаемся ")
		--trid,ms=moveOrder(0,watch_list.order_offer.ordernum,toPrice(code,sbid+watch_list.minstep))
		local trid,ms=killOrder(watch_list.order_offer.ordernum,code,watch_list.class)
		if trid~=nil then transactions[trid]="offer" watch_list.status_offer="waitcancellclose" end
		toLog(log,ms)
	elseif watch_list.status_offer=="close" and bbid>watch_list.order_offer.price and watch_list.open_price_offer-watch_list.order_offer.price>=(watch_list.tp+1)*watch_list.minstep then
		toLog(log,"Offer. Стоим на закрытие на уровне лучше чем тейк-профит и перед нами появилась заявка - передвигаемся")
		toLog(log,"Status="..watch_list.status_offer.." OrderPrice="..watch_list.order_offer.price.." OpenPrice="..watch_list.open_price_offer.." TP="..watch_list.tp)
		local trid,ms=killOrder(watch_list.order_offer.ordernum,code,watch_list.class)
		if trid~=nil then transactions[trid]="offer" watch_list.status_offer="waitcancellclose" end
		toLog(log,ms)
	end
	toLog(log,"Trade Offer ended. "..(os.clock()-st)..' status='..watch_list.status_offer)
end
function FindOfferClosePrice(security,price)
	local tp_level=watch_list.tp*watch_list.minstep
	local bbid=tonumber(getParamEx(watch_list.class,security,"BID").param_value)
	local lasttrade=tonumber(getParamEx(watch_list.class,security,"LAST").param_value)
	if price-tp_level>bbid then
		toLog(log,"Best Bid. tp="..(bbid+watch_list.minstep))
		return bbid+watch_list.minstep
	else
		local ql2=getQuoteLevel2(watch_list.class,security)
		beg=findBegemot("bid",ql2.bid,ql2.bid_count,security)
		if beg==0 then
			if lasttrade>price+watch_list.minstep then
				toLog(log,"Best Bid.No beg. Bad trade. tp="..(bbid+-watch_list.minstep))
				return bbid+watch_list.minstep
			else
				toLog(log,"At TP-level. No beg. tp="..price-tp_level)
				return price-tp_level
			end
		else
			if price+tp_level<beg then
				toLog(log,"Before beg. tp="..(beg+watch_list.minstep))
				return beg+watch_list.minstep
			else
				toLog(log,"At TP-level. Have beg. tp="..(price-tp_level))
				return price-tp_level
			end
		end
	end
end
function FindBidClosePrice(security,price)
	local tp_level=watch_list.tp*watch_list.minstep
	local bask=tonumber(getParamEx(watch_list.class,security,"OFFER").param_value)
	local lasttrade=tonumber(getParamEx(watch_list.class,security,"LAST").param_value)
	if price+tp_level<bask then
		toLog(log,"Best ask. tp="..(bask-watch_list.minstep))
		return bask-watch_list.minstep
	else
		local ql2=getQuoteLevel2(watch_list.class,security)
		beg=findBegemot("ask",ql2.offer,ql2.bid_count,security)
		if beg==0 then
			if lasttrade<price-watch_list.minstep then
				toLog(log,"Best ask.No beg. Bad trade. tp="..(bask-watch_list.minstep))
				return bask-watch_list.minstep
			else
				toLog(log,"At TP-level. No beg. tp="..price+tp_level)
				return price+tp_level
			end
		else
			if price+tp_level>beg then
				toLog(log,"Before beg. tp="..(beg-watch_list.minstep))
				return beg-watch_list.minstep
			else
				toLog(log,"At TP-level. Have beg. tp="..price+tp_level)
				return price+tp_level
			end
		end
	end
end

function OnQuoteDo(class_code,sec_code)
	local st=os.clock()
	local ql2=getQuoteLevel2(class_code,sec_code)
	if ql2==nil then toLog(log,"------- Can`t get glass for "..class_code..sec_code) is_run=false return end
	local begbid,begoffer=0,0
	if ql2.bid_count~=0 and watch_list.volume_bid~=0 then begbid=findBegemot("bid",ql2.bid,ql2.bid_count,sec_code)	end
	if ql2.offer_count~=0 and watch_list.volume_offer~=0 then begoffer=findBegemot("offer",ql2.offer,ql2.offer_count,sec_code)	end
	if watch_list.bidEnable==1 then TradeBid(watch_list.position_bid,begbid,begoffer,tonumber(ql2.bid[tonumber(ql2.bid_count)].price),tonumber(ql2.bid[tonumber(ql2.bid_count)-1].price),sec_code) end
	if watch_list.offerEnable==1 then TradeOffer(watch_list.position_offer,begoffer,begbid,tonumber(ql2.offer[1].price),tonumber(ql2.offer[2].price),sec_code) end
	watch_list.position_bid=begbid
	watch_list.position_offer=begoffer
	toLog(log,"OnQuote. "..(os.clock()-st))
end
function OnOrderDo(order)
	local st=os.clock()
	if order==nil then toLog(log,"Nil order") return end
	toLog(log,"OnOrder start. TrId="..order.trans_id.." Num="..order.ordernum.." Status="..tostring(orderflags2table(order.flags).active))
	if watch_list.order_bid.ordernum~=nil then
		toLog(log,"Bid status="..watch_list.status_bid.." OrderNum="..watch_list.order_bid.ordernum)
	else
		toLog(log,"Bid status="..watch_list.status_bid)
	end
	if watch_list.order_offer.ordernum~=nil then
		toLog(log,"Offer status="..watch_list.status_offer.." OrderNum="..watch_list.order_offer.ordernum)
	else
		toLog(log,"Offer status="..watch_list.status_offer)
	end
	if bad_transactions[order.trans_id]~="" and bad_transactions[order.trans_id]~=nil then
		toLog(log,"Bad transaction arrived ID="..order.trans_id.." Status="..bad_transactions[order.trans_id])
		toLog(log,order)
		toLog(log,orderflags2table(order.flags))
		if orderflags2table(order.flags).active then
			local tr,ms=killOrder(order.ordernum,order.seccode,order.class_code)
			if tr~=nil then bad_transactions[tr]="cancell"..bad_transactions[order.trans_id] end
			toLog(log,ms)
		end
		if orderflags2table(order.flags).done then toLog(log,"ERROR! Exess transaction done") end
		-- do smthng with done orders
		bad_transactions[order.trans_id]=""
	end
	if transactions[order.trans_id]=="bid" then
		toLog(log,"New bid order. Cur_status="..watch_list.status_bid.." LastTransID="..watch_list.trans_bid)
		if watch_list.trans_bid==order.trans_id --[[or watch_list.trans_bid==0]] then
			watch_list.order_bid={}
			watch_list.order_bid=order
			watch_list.status_bid=string.gsub(watch_list.status_bid,"wait","")
		end
		if order.balance==0 then
			transactions[order.trans_id]=""
			watch_list.open_price_bid=order.price
			toLog(log,watch_list.status_bid.." order filled! Balance="..order.balance)
			if order.trans_id~=watch_list.trans_bid and watch_list.trans_bid~=0 then
				toLog(log,"Warning! Exess transaction sended ID="..watch_list.trans_bid)
				bad_transactions[watch_list.trans_bid]=watch_list.status_bid
				--watch_list.trans_bid=0
				watch_list.trans_bid=order.trans_id
				watch_list.order_bid={}
				watch_list.order_bid=order
				watch_list.status_bid=string.gsub(watch_list.status_bid,"wait","")
			end
			if watch_list.status_bid=="open" or watch_list.status_bid=="" or watch_list.status_bid=="cancell" then
				watch_list.open_price_bid=order.price
				local pr=FindBidClosePrice(order.seccode,order.price)
				local trid,ms=sendLimit(order.class_code,order.seccode,"S",toPrice(order.seccode,pr),watch_list.volume,watch_list.account,watch_list.client_code,"BegemotCB")
				if trid~=nil then transactions[trid]="bid" watch_list.status_bid="waitclose" watch_list.trans_bid=trid end
				toLog(log,ms)
			elseif watch_list.status_bid=="close" or watch_list.status_bid=="cancellclose" then
				toLog(log,"Start new cycle.")
				watch_list.order_bid={}
				watch_list.open_price_bid=0
				watch_list.status_bid=""
			end
		end
		--if order.trans_id==watch_list.trans_bid then watch_list.trans_bid=0 end
		if orderflags2table(order.flags).cancelled then 
			transactions[order.trans_id]=""
			if watch_list.status_bid=="" then toLog(log,"Bid order cancelled") watch_list.order_bid={} end
			if watch_list.status_bid=="cancell" then watch_list.status_bid="" toLog(log,"Open bid order cancelled. Try to set new.") OnQuoteDo(order.class_code,order.seccode) end
			if watch_list.status_bid=="cancellclose" then 
				local pr=FindBidClosePrice(order.seccode,watch_list.open_price_bid)
				local trid,ms=sendLimit(order.class_code,order.seccode,"S",toPrice(order.seccode,pr),watch_list.volume,watch_list.account,watch_list.client_code,"BegemotCB")
				if trid~=nil then transactions[trid]="bid" watch_list.status_bid="waitclose" watch_list.trans_bid=trid end
				toLog(log,ms)
			end
		end
	elseif transactions[order.trans_id]=="offer" then
		toLog(log,"New offer order. Cur_status="..watch_list.status_offer.." LastTransID="..watch_list.trans_offer)
		if watch_list.trans_offer==order.trans_id --[[or watch_list.trans_offer==0]] then
			watch_list.order_offer={}
			watch_list.order_offer=order
			watch_list.status_offer=string.gsub(watch_list.status_offer,"wait","")
		end
		if order.balance==0 then
			transactions[order.trans_id]=""
			toLog(log,watch_list.status_offer.." order filled! Balance="..order.balance)
			if order.trans_id~=watch_list.trans_offer and watch_list.trans_offer~=0 then
				toLog(log,"Warning! Exess transaction sended ID="..watch_list.trans_offer)
				bad_transactions[watch_list.trans_offer]=watch_list.status_offer
				--watch_list.trans_offer=0
				watch_list.trans_offer=order.trans_id
				watch_list.order_offer={}
				watch_list.order_offer=order
				watch_list.status_offer=string.gsub(watch_list.status_offer,"wait","")
			end
			if watch_list.status_offer=="open" or watch_list.status_offer=="" or watch_list.status_offer=='cancell' then
				watch_list.open_price_offer=order.price
				local pr=FindOfferClosePrice(order.seccode,order.price)
				local trid,ms=sendLimit(order.class_code,order.seccode,"B",toPrice(order.seccode,pr),watch_list.volume,watch_list.account,watch_list.client_code,"BegemotCO")
				if trid~=nil then transactions[trid]="offer" watch_list.status_offer="waitclose" watch_list.trans_offer=trid end
				toLog(log,ms)
			elseif watch_list.status_offer=="close" or watch_list.status_offer=='cancellclose' then
				toLog(log,"Start new cycle.")
				watch_list.order_offer={}
				watch_list.open_price_offer=0
				watch_list.status_offer=""
			end
		end
		--if order.trans_id==watch_list.trans_offer then watch_list.trans_offer=0 end
		if orderflags2table(order.flags).cancelled then 
			transactions[order.trans_id]=""
			if watch_list.status_offer=="" then toLog(log,"Offer order cancelled") watch_list.order_offer={} end
			if watch_list.status_offer=="cancell" then watch_list.status_offer='' toLog(log,"Open offer order cancelled. Try to set new.") OnQuoteDo(order.class_code,order.seccode) end
			if watch_list.status_offer=="cancellclose" then 
				local pr=FindOfferClosePrice(order.seccode,order.price)
				local trid,ms=sendLimit(order.class_code,order.seccode,"B",toPrice(order.seccode,pr),watch_list.volume,watch_list.account,watch_list.client_code,"BegemotCO")
				if trid~=nil then transactions[trid]="offer" watch_list.status_offer="waitclose" watch_list.trans_offer=trid end
				toLog(log,ms)
			end
		end
	else
		toLog(log,"____ some shit on OnOrder()_____")
		toLog(log,order)
		toLog(log,"________________________________")
	end
	toLog(log,"Final BidStatus="..watch_list.status_bid.." OfferStatus="..watch_list.status_offer)
	toLog(log,"OnOrder end. "..(os.clock()-st))
end
function OnAllTradeDo(trade)
	--local st=os.clock()
	local s="OnAllTrade. Price="..trade
	if watch_list.status_bid=="close" then s=s..' BidOpenPrice='..watch_list.open_price_bid end
	if watch_list.status_offer=="close" then s=s..' OfferOpenPrice='..watch_list.open_price_offer end
	toLog(log,s)
	--toLog(log,trade)
	-- check bad data
	if watch_list.status_bid=="close" and trade<watch_list.open_price_bid-watch_list.minstep then
		toLog(log,"Bid. Сделка ниже цены открытия. Trade="..trade.." OpenPrice="..watch_list.open_price_bid.." S="..watch_list.status_bid)
		local pr=tonumber(FindBidClosePrice(watch_list.code,watch_list.open_price_bid))
		if pr~=watch_list.order_bid.price and pr+watch_list.minstep~=watch_list.order_bid.price then
			toLog(log,"Bid. Необходимо передвинуть заявку. CurPrice="..watch_list.order_bid.price.." CalculatedPrice="..pr)
			local trid,ms=killOrder(watch_list.order_bid.ordernum,watch_list.code,watch_list.class)
			if trid~=nil then watch_list.status_bid="waitcancellclose" transactions[trid]="bid" end
			toLog(log,ms)
		end
	end
	if watch_list.status_offer=="close" and trade>watch_list.open_price_offer+watch_list.minstep then
		toLog(log,"Offer. Сделка выше цены открытия. Trade="..trade.." OpenPrice="..watch_list.open_price_offer.." S="..watch_list.status_offer)
		local pr=tonumber(FindOfferClosePrice(watch_list.code,watch_list.open_price_offer))
		if pr~=watch_list.order_offer.price and pr-watch_list.minstep~=watch_list.order_offer.price then
			toLog(log,"Offer. Необходимо передвинуть заявку. CurPrice="..watch_list.order_offer.price.." CalculatedPrice="..pr)
			local trid,ms=killOrder(watch_list.order_offer.ordernum,watch_list.code,watch_list.class)
			if trid~=nil then watch_list.status_offer="waitcancellclose" transactions[trid]="offer" end
			toLog(log,ms)
		end
	end
	--toLog(log,"OnAllTrade. "..(os.clock()-st))
end
function OnTransReplyDo(reply)
	if is_run and reply.R~=nil then
		if transactions[reply.R]=="cancellopenbid" then
			toLog(log,"OnTransReply found cancellbid")
			watch_list.open_order_bid={}
			transactions[reply.R]=""
		elseif transactions[reply.R]=="cancellopenoffer" then
			toLog(log,"OnTransReply found cancelloffer")
			watch_list.open_order_offer={}
			transactions[reply.R]=""
		elseif reply.status~=3 and transactions[reply.R]~=nil then
			toLog(log,"Error on transaction "..reply.R.." "..transactions[reply.R])
			toLog(log,reply.result_msg)
			transactions[reply.R]=""
		end
	end
end
function OnInitDo()
	is_run=getSettings(getScriptPath().."\\"..settings_file)
	toLog(log,"Is_run="..tostring(is_run))
	--[[
	if is_run then
		toLog(log,"Start prepare")
		local class_code=getSecurityInfo("",watch_list.code).class_code
		toLog(log,class_code)
		local ql2=getQuoteLevel2(class_code,watch_list.code)
		toLog(log,"stakan found")
		local begbid,begoffer=0,0
		if ql2.bid_count~=0 and watch_list.volume_bid~=0 then
			begbid=findBegemot("bid",ql2.bid,ql2.bid_count,watch_list.code)
		end
		if ql2.offer_count~=0 and watch_list.volume_offer~=0 then
			begoffer=findBegemot("offer",ql2.offer,ql2.offer_count,watch_list.code)
		end
		toLog(log,begbid)
		toLog(log,begoffer)
		TradeBid(0,begbid,begoffer,watch_list.code)
		TradeOffer(0,begoffer,begbid,watch_list.code)
		watch_list.position_bid=begbid
		watch_list.position_offer=begoffer
	end
	]]--
	is_run=true
	toLog(log,"Initialization finished. ")
end

function OnStop()
	toLog(log,"Stop button pressed!")
	is_run=false
	if watch_list.bidEnable==1 and watch_list.order_bid~=nil then _,_=killOrder(watch_list.order_bid.ordernum) end
	if watch_list.offerEnable==1 and watch_list.order_offer~=nil then _,_=killOrder(watch_list.order_offer.ordernum) end
end
function OnInit()
	log=getScriptPath().."\\"..log
	toLog(log,"Initialization...")
end
function OnQuote(class,sec)
	if is_run and watch_list.code==sec then
		local tmp={
		["class"]=class,
		["security"]=sec
		}
		table.insert(quotes,tmp)
	elseif class==nil or sec==nil then
		toLog(log,"Nil update OnQuote")
	end
end
function OnOrder(order)
	if is_run and watch_list.code==order.seccode then
		table.insert(orders,order)
	elseif order==nil then
		toLog(log,"Nil update on Order")
	end
end
--[[function OnAllTrade(trade)
	if is_run and watch_list.code==trade.seccode then
		table.insert(all_trades,trade)
	elseif trade==nil then
		toLog(log,"Nil update on AllTrade")
	end
end]]
function OnParam(pclass,psec)
	if not is_run or psec~=watch_list.code then return end
	local t=tonumber(getParamEx(pclass,psec,"LAST").param_value)
	if last_trade~=t then table.insert(on_param,t) last_trade=t end
end
function OnTransReply(reply)
	if is_run then
		if reply==nil then toLog(log,"Nil update on transreply") return end
		table.insert(trans_replies,reply)
	end
end

function main()
	OnInitDo()
	toLog(log,"Main start")
	while is_run do
		if #trans_replies~=0 then
			local trrep=table.remove(trans_replies,1)
			if trrep~=nil then OnTransReplyDo(trrep) else toLog(log,"Nil TransReply on remove") end
		elseif on_init then
			OnInitDo()
			on_init=false
		elseif #orders~=0 then
			local order=table.remove(orders,1)
			if order~=nil then OnOrderDo(order) else toLog(log,"Nil order on remove") end
		elseif #quotes~=0 then
			local tmp=table.remove(quotes,1)
			if tmp~=nil then OnQuoteDo(tmp.class,tmp.security) else toLog(log,"Nil Quote on remove") end
		elseif #on_param~=0 then
			local trade=table.remove(on_param,1)
			if trade~=nil then OnAllTradeDo(trade) else toLog(log,"Nil trade on remove") end
		else
			sleep(1)
		end
	end
	toLog(log,"Main ended")
end