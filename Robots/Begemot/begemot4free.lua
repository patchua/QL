-- version 0.2
require"QL"
require"luaxml"
log="begemot.log"
settings_file="settings.xml"
watch_list={}
transactions={}
quotes={}
orders={}
all_trades={}
trans_replies={}
is_run=false

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
	watch_list.class=file:find("class").value
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
function TradeBid(cur_begbid,new_begbid,new_begoffer,sec_code)
	toLog(log,"Trade BId started. CBBid="..cur_begbid.." NBBid="..new_begbid.." NBOffer="..new_begoffer.." Sec="..sec_code)
	-- если бегемот исчез и есть заявка на открытие - снять
	if watch_list.status_bid=="open" and new_begbid==0 then
		toLog(log,"Bid. если бегемот исчез и есть заявка на открытие - снять ")
		local trid,ms=killOrder(watch_list.order_bid.ordernum)
		if trid~=nil then transactions[trid]="bid" watch_list.status_bid="wait"	end
		toLog(log,ms)
	-- если бегемот появился и "условия"- выставить заявку
	elseif new_begbid~=0 and watch_list.status_bid=="" and (new_begoffer==0 or new_begoffer>new_begbid+(1+watch_list.tp)*watch_list.minstep) then
		toLog(log,"BId. если бегемот появился и условия- выставить заявку")
		local trid,ms=sendLimit(watch_list.class,sec_code,"B",toPrice(sec_code,new_begbid+watch_list.minstep),watch_list.volume,watch_list.account,watch_list.client_code)
		if trid~=nil then	transactions[trid]="bid" watch_list.status_bid="waitopen" end
		toLog(log,ms)
	-- если бегемот передвинулся - передвинуть заявку
	elseif new_begbid~=0 and cur_begbid~=0 and cur_begbid~=new_begbid and watch_list.status_bid=="open" then
		toLog(log,"Bid. если бегемот передвинулся - передвинуть заявку. num="..watch_list.order_bid.ordernum.." pr="..toPrice(sec_code,new_begbid+watch_list.minstep))
		local trid,ms=moveOrder(0,watch_list.order_bid.ordernum,toPrice(sec_code,new_begbid+watch_list.minstep))
		if trid~=nil then transactions[trid]="bid" watch_list.status_bid="waitopen" end
		toLog(log,ms)
	-- если стоим на закрытие и ниже повился бегемот - передвигаемся под него
	elseif watch_list.status_bid=="close" and new_begoffer<watch_list.order_bid.price then
		toLog(log,"BId. если стоим на закрытие и ниже повился бегемот - передвигаемся под него")
		local trid,ms=moveOrder(0,watch_list.order_bid.ordernum,toPrice(sec_code,new_begoffer-watch_list.minstep))
		if trid~=nil then transactions[trid]="bid" watch_list.status_bid="waitclose" end
		toLog(log,ms)
	-- если стоим на закрытие и бегемота нет и можно "улучшить" место оставаясь лучшим офером - передвигаемся 
	elseif watch_list.status_bid=="close" and new_begoffer==0 and watch_list.order_bid.price<getParamEx(watch_list.class,sec_code,"OFFER").param_value-watch_list.minstep then
		toLog(log,"BId. если стоим на закрытие и бегемота нет и можно улучшить место оставаясь лучшим офером - передвигаемся ")
		trid,ms=moveOrder(0,watch_list.order_bid.ordernum,toPrice(sec_code,getParamEx(watch_list.class,sec_code,"OFFER").param_value-watch_list.minstep))
		if trid~=nil then transactions[trid]="bid" watch_list.status_bid="waitclose" end
		toLog(log,ms)
	end
	--toLog(log,"TradeBid ended. "..(os.clock()-st))
end
function TradeOffer(cur_begoffer,new_begoffer,new_begbid,code)
	--local st=os.clock()
	toLog(log,"Trade Offer started. CBOffer="..cur_begoffer.." NBOffer="..new_begoffer.." NBBid="..new_begbid.." Sec="..code)
	-- если бегемот исчез и есть заявка на открытие - снять
	if watch_list.status_offer=="open" and new_begoffer==0 then
		toLog(log,"Offer. если бегемот исчез и есть заявка на открытие - снять ")
		local trid,ms=killOrder(watch_list.order_offer.ordernum)
		if trid~=nil then transactions[trid]="offer" watch_list.status_offer="wait" end
		toLog(log,ms)
	-- если бегемот появился и "условия"- выставить заявку
	elseif new_begoffer~=0 and watch_list.status_offer=="" and (new_begbid==0 or new_begbid<new_begoffer-(1+watch_list.tp)*watch_list.minstep) then
		toLog(log,"Offer. если бегемот появился и условия- выставить заявку")
		local trid,ms=sendLimit(watch_list.class,code,"S",toPrice(code,new_begoffer-watch_list.minstep),watch_list.volume,watch_list.account,watch_list.client_code)
		if trid~=nil then transactions[trid]="offer" watch_list.status_offer="waitopen" end
		toLog(log,ms)
	-- если бегемот передвинулся - передвинуть заявку
	elseif new_begoffer~=0 and cur_begoffer~=0 and cur_begoffer~=new_begoffer and watch_list.status_offer=="open" then
		toLog(log,"Offer. если бегемот передвинулся - передвинуть заявку. num="..watch_list.order_offer.ordernum.." pr="..toPrice(code,new_begoffer-watch_list.minstep))
		local trid,ms=moveOrder(0,watch_list.order_offer.ordernum,toPrice(code,new_begoffer-watch_list.minstep))
		if trid~=nil then transactions[trid]="offer" watch_list.status_offer="waitopen" end
		toLog(log,ms)
	-- если стоим на закрытие и ниже повился бегемот - передвигаемся под него
	elseif watch_list.status_offer=="close" and new_begbid>watch_list.order_offer.price then
		toLog(log,"Offer. если стоим на закрытие и ниже повился бегемот - передвигаемся под него")
		local trid,ms=moveOrder(0,watch_list.order_offer.ordernum,toPrice(code,new_begbid+watch_list.minstep))
		if trid~=nil then transactions[trid]="offer" watch_list.status_offer="waitclose" end
		toLog(log,ms)
	-- если стоим на закрытие и бегемота нет и можно "улучшить" место оставаясь лучшим офером - передвигаемся 
	elseif watch_list.status_offer=="close" and new_begbid==0 and watch_list.order_offer.price>getParamEx(watch_list.class,code,"BID").param_value+watch_list.minstep then
		toLog(log,"Offer. если стоим на закрытие и бегемота нет и можно улучшить место оставаясь лучшим офером - передвигаемся ")
		trid,ms=moveOrder(0,watch_list.order_offer.ordernum,toPrice(code,getParamEx(getSecurityInfo("",code).class_code,code,"BID").param_value+watch_list.minstep))
		if trid~=nil then transactions[trid]="offer" watch_list.status_offer="waitclose" end
		toLog(log,ms)
	end
	--toLog(log,"Trade Offer ended. "..(os.clock()-st))
end
function FindOfferClosePrice(security,price)
	local tp_level=watch_list.tp*watch_list.minstep
	local bbid=tonumber(getParamEx(watch_list.class,security,"BID").param_value)
	if price-tp_level>bbid then
		toLog(log,"tp="..(bbid+watch_list.minstep))
		return bbid+watch_list.minstep
	else
		local ql2=getQuoteLevel2(watch_list.class,security)
		beg=findBegemot("bid",ql2.bid,ql2.bid_count,security)
		if beg==0 then
			toLog(log,"tp="..(price-tp_level))
			return price-tp_level
		else
			if price+tp_level<beg then
				toLog(log,"tp="..(beg+watch_list.minstep))
				return beg+watch_list.minstep
			else
				toLog(log,"tp="..(price-tp_level))
				return price-tp_level
			end
		end
	end
end
function FindBidClosePrice(security,price)
	local tp_level=watch_list.tp*watch_list.minstep
	local bask=tonumber(getParamEx(watch_list.class,security,"OFFER").param_value)
	if price+tp_level<bask then
		toLog(log,"tp="..(bask-watch_list.minstep))
		return bask-watch_list.minstep
	else
		local ql2=getQuoteLevel2(gwatch_list.class,security)
		beg=findBegemot("ask",ql2.offer,ql2.bid_count,security)
		if beg==0 then
			toLog(log,"tp="..(price+tp_level))
			return price+tp_level
		else
			if price+tp_level>beg then
				toLog(log,"tp="..(beg-watch_list.minstep))
				return beg-watch_list.minstep
			else
				toLog(log,"tp="..price+tp_level)
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
	if watch_list.bidEnable==1 then TradeBid(watch_list.position_bid,begbid,begoffer,sec_code) end
	if watch_list.offerEnable==1 then TradeOffer(watch_list.position_offer,begoffer,begbid,sec_code) end
	watch_list.position_bid=begbid
	watch_list.position_offer=begoffer
	toLog(log,"OnQuote. "..(os.clock()-st))
end
function OnOrderDo(order)
	local st=os.clock()
	if order==nil then toLog(log,"Nil order") return end
	toLog(log,"OnOrder start. TrId="..order.trans_id.." Num="..order.ordernum)
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
	if transactions[order.trans_id]=="bid" then
		toLog(log,"New bid order. Cur_status="..watch_list.status_bid)
		watch_list.order_bid={}
		watch_list.order_bid=order
		watch_list.status_bid=string.gsub(watch_list.status_bid,"wait","")
		if order.balance==0 then
			transactions[order.trans_id]=""
			toLog(log,watch_list.status_bid.." order filled! Balance="..order.balance)
			if watch_list.status_bid=="open" or watch_list.status_bid=="" then
				watch_list_open_price_bid=order.price
				local pr=FindBidClosePrice(order.seccode,order.price)
				local trid,ms=sendLimit(order.class_code,order.seccode,"S",toPrice(order.seccode,pr),watch_list.volume,watch_list.account,watch_list.client_code,"closebid")
				if trid~=nil then transactions[trid]="bid" watch_list.status_bid="waitclose" end
				toLog(log,ms)
			elseif watch_list.status_bid=="close" then
				toLog(log,"Start new cycle.")
				watch_list.order_bid={}
				watch_list.open_price_bid=0
				watch_list.status_bid=""
			end
		end
		if watch_list.status_bid=="" and orderflags2table(order.flags).cancelled==1 then 
			transactions[order.trans_id]=""
			toLog(log,"Bid order cancelled")
			watch_list.order_bid={}
		end
	elseif transactions[order.trans_id]=="offer" then
		toLog(log,"New offer order. Cur_status="..watch_list.status_offer)
		watch_list.order_offer={}
		watch_list.order_offer=order
		watch_list.status_offer=string.gsub(watch_list.status_offer,"wait","")
		if order.balance==0 then
			transactions[order.trans_id]=""
			toLog(log,watch_list.status_offer.." order filled! Balance="..order.balance)
			if watch_list.status_offer=="open" or watch_list.status_offer=="" then
				watch_list.open_price_offer=order.price
				local pr=FindOfferClosePrice(order.seccode,order.price)
				local trid,ms=sendLimit(order.class_code,order.seccode,"B",toPrice(order.seccode,pr),watch_list.volume,watch_list.account,watch_list.client_code,"closeoffer")
				if trid~=nil then transactions[trid]="offer" watch_list.status_offer="waitclose" end
				toLog(log,ms)
			elseif watch_list.status_offer=="close" then
				toLog(log,"Start new cycle.")
				watch_list.order_offer={}
				watch_list.open_price_offer=0
				watch_list.status_offer=""
			end
		end
		if watch_list.status_offer=="" and orderflags2table(order.flags).cancelled==1 then 
			transactions[order.trans_id]=""
			toLog(log,"Bid order cancelled")
			watch_list.order_offer={}
		end
	else
		toLog(log,"____ some shit on OnOrder()_____")
		toLog(log,order)
		toLog(log,"________________________________")
	end
	toLog(log,"OnOrder end. "..(os.clock()-st))
end
function OnAllTradeDo(trade)
	local st=os.clock()
	toLog(log,"OnAllTrade start")
	--toLog(log,trade)
	-- check bad data
	if trade==nil then toLog(log,"-------------------Nil trade at OnAllTradesDo()") return end
	if trade.price==nil then toLog(log,"---------Nil Trade.price ") toLog(log,trade) return end
	--
	if watch_list.status_bid=="close" and trade.price<watch_list.open_price_bid then
		toLog(log,"Trade lower then bid open price. Trade="..trade.price.." OpenPrice="..watch_list.open_price_bid.." S="..watch_list.status_bid)
		local ql2=getQuoteLevel2(trade.class_code,trade.seccode)
		local beg=findBegemot("bid",ql2.bid,ql2.bid_count,trade.seccode)
		local bask=tonumber(getParamEx(watch_list.class,trade.seccode,"OFFER").param_value)
		if beg==0 then
			toLog(log,"No begemots. BOffer="..bask)
			local trid,ms=moveOrder(0,watch_list.order_bid.ordernum,toPrice(trade.seccode,bask-watch_list.minstep))
			if trid~=nil then transactions[trid]="bid" watch_list.status_bid="waitclose" end
			toLog(log,ms)
		else
			local tp_level=beg+watch_list.tp*watch_list.minstep
			toLog(log,"Begemot still in glass "..beg.." BOffer="..bask.." TP_level="..tp_level)
			if tp_level<bask then
				local trid,ms=moveOrder(0,watch_list.order_bid.ordernum,toPrice(trade.seccode,bask-watch_list.minstep))
				if trid~=nil then transactions[trid]="bid" watch_list.status_bid="waitclose" end
				toLog(log,ms)
			else
				local trid,ms=moveOrder(0,watch_list.order_bid.ordernum,toPrice(trade.seccode,tp_level))
				if trid~=nil then transactions[trid]="bid" watch_list.status_bid="waitclose" end
				toLog(log,ms)
			end
		end
	end
	if watch_list.status_offer=="close" and trade.price>watch_list.open_price_offer then
		toLog(log,"Trade lower then offer open price. Trade="..trade.price.." OpenPrice="..watch_list.open_price_offer.." S="..watch_list.status_offer)
		local ql2=getQuoteLevel2(trade.class_code,trade.seccode)
		local beg=findBegemot("offer",ql2.offer,ql2.offer_count,trade.seccode)
		local bbid=tonumber(getParamEx(watch_list.class,trade.seccode,"BID").param_value)
		if beg==0 then
			toLog(log,"No begemots. BBid="..bid)
			local trid,ms=moveOrder(0,watch_list.order_offer.ordernum,toPrice(trade.seccode,bbid+watch_list.minstep))
			if trid~=nil then transactions[trid]="offer" watch_list.status_offer="waitclose" end
			toLog(log,ms)
		else
			local tp_level=beg-watch_list.tp*watch_list.minstep
			toLog(log,"Begemot still in glass "..beg.." BBid="..bbid.." TP_level="..tp_level)
			if tp_level>bbid then
				local trid,ms=moveOrder(0,watch_list.order_offer.ordernum,toPrice(trade.seccode,bbid+watch_list.minstep))
				if trid~=nil then transactions[trid]="offer" watch_list.status_offer="waitclose" end
				toLog(log,ms)
			else
				local trid,ms=moveOrder(0,watch_list.order_offer.ordernum,toPrice(trade.seccode,tp_level))
				if trid~=nil then transactions[trid]="offer" watch_list.status_offer="waitclose" end
				toLog(log,ms)
			end
		end
	end
	toLog(log,"OnAllTrade. "..(os.clock()-st))
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
	end
end
function OnOrder(order)
	if is_run and watch_list.code==order.seccode then
		table.insert(orders,order)
	end
end
function OnAllTrade(trade)
	if is_run and watch_list.code==trade.seccode then
		table.insert(all_trades,trade)
	end
end
function OnTransReply(reply)
	if is_run then
		table.insert(trans_replies,reply)
	end
end

function main()
	OnInitDo()
	toLog(log,"Main start")
	while is_run do
		if #trans_replies~=0 then
			OnTransReplyDo(table.remove(trans_replies,1))
		elseif on_init then
			OnInitDo()
			on_init=false
		elseif #orders~=0 then
			OnOrderDo(table.remove(orders,1))
		elseif #quotes~=0 then
			local tmp=table.remove(quotes,1)
			OnQuoteDo(tmp.class,tmp.security)
		elseif #all_trades~=0 then
			OnAllTradeDo(table.remove(all_trades,1))
		else
			sleep(1)
		end
	end
	toLog(log,"Main ended")
end