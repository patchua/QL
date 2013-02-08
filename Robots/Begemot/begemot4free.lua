require"QL"
log="begemot.log"
watch_list={}
transactions={}
quotes={}
orders={}
all_trades={}
trans_replies={}
is_run=false
on_init=false
function getSettings(path)
	local file=io.open(path)
	if file==nil then
		message("Begemot can`t open settings file!",3)
		toLog(log,"File can`t be openned!")
		return false
	else 
		toLog(log,"File oppened")
		local added=false
		local st,een
		for line in file:lines() do
			local code=""
			st,een=string.find(line,"%S;")
			code=string.sub(line,0,een-1)
			watch_list.code=code
			st,een=string.find(line,";%d+;",een)
			watch_list.volume_offer=tonumber(string.sub(line,st+1,een-1))
			st,een=string.find(line,";%d+;",een)
			watch_list.volume_bid=tonumber(string.sub(line,st+1,een-1))
			st,een=string.find(line,";%d+;",een)
			watch_list.tp=tonumber(string.sub(line,st+1,een-1))
			st,een=string.find(line,";%d+;",een)
			watch_list.volume=string.sub(line,st+1,een-1)
			st=een
			_,een=string.find(line,";",st+1)
			watch_list.account=string.sub(line,st+1,een-1)
			toLog(log,st.." "..een)
			st=een
			_,een=string.find(line,";",st+1)
			toLog(log,st.." "..een)
			watch_list.client_code=string.sub(line,st+1,een-1)
			watch_list.position_bid=0
			watch_list.position_offer=0
			watch_list.open_order_bid={}
			watch_list.close_order_bid={}
			watch_list.open_order_offer={}
			watch_list.close_order_offer={}
			watch_list.minstep=getParamEx(getSecurityInfo("",code).class_code,code,"SEC_PRICE_STEP").param_value
			toLog(log,"Sc found c="..code.." vol_offer="..watch_list.volume_offer
			.." vol_bid="..watch_list.volume_bid
			.." tp="..watch_list.tp
			.." step="..watch_list.minstep
			.." vol="..watch_list.volume
			.." acc="..watch_list.account
			.." clc="..watch_list.client_code)
			added=true
			break
		end
		file:close()
		if not added then
			toLog(log,"No securities")
			return false
		else
			toLog(log," Securities added to watch list")
			return true
		end
	end
end
function findBegemot(type,table,count,sec)
	local i
	local st=os.clock()
	toLog(log,"findBegemot started type="..type.." sec="..sec.." count="..count)
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
	toLog(log,"findBegemot ended. "..(os.clock()-st))
end
function AnalyzeBegemot(sec_code,old_value,new_value)
	--local st=os.clock()
	--toLog(log,"Analyze started old="..old_value.." new="..new_value)
	if old_value==0 and new_value>0 then
		toLog(log,"Begemot found! sec="..sec_code.." Price="..new_value)
		--message("Begemot found! sec="..sec_code.." Price="..new_value,2)
		return new_value
	elseif old_value~=0 and new_value==0 then
		toLog(log,"Begemot escaped! sec="..sec_code)
		--message("Begemot escaped! sec="..sec_code,2)
		return 0
	elseif new_value~=0 and old_value~=0 and old_value~=new_value then
		toLog(log,"Begemot moved! sec="..sec_code.." old_price="..watch_list[sec_code].position_bid.." new_price="..new_value)
		--message("Begemot moved! sec="..sec_code.." old_price="..watch_list[sec_code].position_bid.." new_price="..new_value,2)
		return new_value
	else
		return old_value
	end
	--toLog(log,"Analyze ended. "..(os.clock()-st))
end
function TradeBid(cur_begbid,new_begbid,new_begoffer,sec_code)
	--local st=os.clock()
	--toLog(log,"Trade BId started")
	-- если бегемот исчез и есть заявка на открытие - снять
	if watch_list.open_order_bid.ordernum~=nil and new_begbid==0 and getPosFromTable(transactions,"cancellopenbid")<0 then
			toLog(log,"Bid. если бегемот исчез и есть заявка на открытие - снять ")
			local trid,ms=killOrder(watch_list.open_order_bid.ordernum)
			if trid~=nil then
				transactions[trid]="cancellopenbid"
			else
				toLog(log,ms)
			end
	-- если бегемот появился и "условия"- выставить заявку
	elseif new_begbid~=0 and watch_list.open_order_bid.ordernum==nil and getPosFromTable(transactions,"openbid")<0 and (new_begoffer==0 or new_begoffer>new_begbid+(1+watch_list.tp)*watch_list.minstep) then
			toLog(log,"BId. если бегемот появился и условия- выставить заявку")
			local trid,ms=sendLimit(getSecurityInfo("",sec_code).class_code,sec_code,"B",toPrice(sec_code,new_begbid+watch_list.minstep),watch_list.volume,watch_list.account,watch_list.client_code)
			if trid~=nil then
				transactions[trid]="openbid"
			else
				toLog(log,ms)
			end
	-- если бегемот передвинулся - передвинуть заявку
	elseif new_begbid~=0 and cur_begbid~=0 and cur_begbid~=new_begbid and watch_list.open_order_bid.ordernum~=nil and watch_list.open_order_bid.balance~=0 and getPosFromTable(transactions,"openbid")<0 then
		toLog(log,"Bid. если бегемот передвинулся - передвинуть заявку. num="..watch_list.open_order_bid.ordernum.." pr="..toPrice(sec_code,new_begbid+watch_list.minstep))
		local trid,ms=moveOrder(0,watch_list.open_order_bid.ordernum,toPrice(sec_code,new_begbid+watch_list.minstep))
		if trid~=nil then
			transactions[trid]="openbid"
		else
			toLog(log,ms)
		end
	-- если стоим на закрытие и ниже повился бегемот - передвигаемся под него
	elseif watch_list.close_order_bid.ordernum~=nil and new_begoffer<watch_list.close_order_bid.price and getPosFromTable(transactions,"closebid")<0 then
		toLog(log,"BId. если стоим на закрытие и ниже повился бегемот - передвигаемся под него")
		local trid,ms=moveOrder(0,watch_list.close_order_bid.ordernum,toPrice(sec_code,new_begoffer-watch_list.minstep))
		if trid~=nil then
			transactions[trid]="closebid"
		else
			toLog(log,ms)
		end
	-- если стоим на закрытие и бегемота нет и можно "улучшить" место оставаясь лучшим офером - передвигаемся 
	elseif watch_list.close_order_bid.ordernum~=nil and new_begoffer==0 and watch_list.close_order_bid.price<getParamEx(getSecurityInfo("",sec_code).class_code,sec_code,"OFFER").param_value-watch_list.minstep and getPosFromTable(transactions,"closebid")<0 then
		toLog(log,"BId. если стоим на закрытие и бегемота нет и можно улучшить место оставаясь лучшим офером - передвигаемся ")
		trid,ms=moveOrder(0,watch_list.close_order_bid.ordernum,toPrice(sec_code,getParamEx(getSecurityInfo("",sec_code).class_code,sec_code,"OFFER").param_value-watch_list.minstep))
		if trid~=nil then
			transactions[trid]="closebid"
		else
			toLog(log,ms)
		end
	end
	--toLog(log,"TradeBid ended. "..(os.clock()-st))
end
function TradeOffer(cur_begoffer,new_begoffer,new_begbid,code)
	--local st=os.clock()
	--toLog(log,"Trade Offer started")
	-- если бегемот исчез и есть заявка на открытие - снять
	if watch_list.open_order_offer.ordernum~=nil and new_begoffer==0 and getPosFromTable(transactions,"cancellopenoffer")<0 then
			toLog(log,"Offer. если бегемот исчез и есть заявка на открытие - снять ")
			local trid,ms=killOrder(watch_list.open_order_offer.ordernum)
			if trid~=nil then
				transactions[trid]="cancellopenoffer"
			else
				toLog(log,ms)
			end
	-- если бегемот появился и "условия"- выставить заявку
	elseif new_begoffer~=0 and watch_list.open_order_offer.ordernum==nil and getPosFromTable(transactions,"openoffer")<0 and (new_begbid==0 or new_begbid<new_begoffer-(1+watch_list.tp)*watch_list.minstep) then
			toLog(log,"Offer. если бегемот появился и условия- выставить заявку")
			local trid,ms=sendLimit(getSecurityInfo("",code).class_code,code,"S",toPrice(code,new_begoffer-watch_list.minstep),watch_list.volume,watch_list.account,watch_list.client_code)
			if trid~=nil then
				transactions[trid]="openoffer"
			else
				toLog(log,ms)
			end
	-- если бегемот передвинулся - передвинуть заявку
	elseif new_begoffer~=0 and cur_begoffer~=0 and cur_begoffer~=new_begoffer and watch_list.open_order_offer.ordernum~=nil and watch_list.open_order_offer.balance~=0 and getPosFromTable(transactions,"openoffer")<0 then
		toLog(log,"Offer. если бегемот передвинулся - передвинуть заявку. num="..watch_list.open_order_offer.ordernum.." pr="..toPrice(code,new_begoffer-watch_list.minstep))
		local trid,ms=moveOrder(0,watch_list.open_order_offer.ordernum,toPrice(code,new_begoffer-watch_list.minstep))
		if trid~=nil then
			transactions[trid]="openoffer"
		else
			toLog(log,ms)
		end
	-- если стоим на закрытие и ниже повился бегемот - передвигаемся под него
	elseif watch_list.close_order_offer.ordernum~=nil and new_begbid>watch_list.close_order_offer.price and getPosFromTable(transactions,"closeoffer")<0 then
		toLog(log,"Offer. если стоим на закрытие и ниже повился бегемот - передвигаемся под него")
		local trid,ms=moveOrder(0,watch_list.close_order_offer.ordernum,toPrice(code,new_begbid+watch_list.minstep))
		if trid~=nil then
			transactions[trid]="closeoffer"
		else
			toLog(log,ms)
		end
	-- если стоим на закрытие и бегемота нет и можно "улучшить" место оставаясь лучшим офером - передвигаемся 
	elseif watch_list.close_order_offer.ordernum~=nil and new_begbid==0 and watch_list.close_order_offer.price>getParamEx(getSecurityInfo("",code).class_code,code,"BID").param_value+watch_list.minstep and getPosFromTable(transactions,"closeoffer")<0 then
		toLog(log,"Offer. если стоим на закрытие и бегемота нет и можно улучшить место оставаясь лучшим офером - передвигаемся ")
		trid,ms=moveOrder(0,watch_list.close_order_offer.ordernum,toPrice(code,getParamEx(getSecurityInfo("",code).class_code,code,"BID").param_value+watch_list.minstep))
		if trid~=nil then
			transactions[trid]="closeoffer"
		else
			toLog(log,ms)
		end
	end
	--toLog(log,"Trade Offer ended. "..(os.clock()-st))
end
function FindOfferClosePrice(security,price)
	--local st=os.clock()
	--toLog(log,"FindOfferClosePrice start")
	local tp_level=watch_list.tp*watch_list.minstep
	local bbid=tonumber(getParamEx(getSecurityInfo("",security).class_code,security,"BID").param_value)
	if price-tp_level>bbid then
		toLog(log,"tp="..(bbid+watch_list.minstep))
		return bbid+watch_list.minstep
	else
		local ql2=getQuoteLevel2(getSecurityInfo("",security).class_code,security)
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
	--toLog(log,"FindOfferClosePrice end. "..(os.clock()-st))
end
function FindBidClosePrice(security,price)
	--local st=os.clock()
	--toLog(log,"FindBidClosePrice start")
	local tp_level=watch_list.tp*watch_list.minstep
	local bask=tonumber(getParamEx(getSecurityInfo("",security).class_code,security,"OFFER").param_value)
	if price+tp_level<bask then
		toLog(log,"tp="..(bask-watch_list.minstep))
		return bask-watch_list.minstep
	else
		local ql2=getQuoteLevel2(getSecurityInfo("",security).class_code,security)
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
	--toLog(log,"FindBidClosePrice end. "..(os.clock()-st))
end

function OnQuoteDo(class_code,sec_code)
	local st=os.clock()
		local ql2=getQuoteLevel2(class_code,sec_code)
		local begbid,begoffer=0,0
		if ql2.bid_count~=0 and watch_list.volume_bid~=0 then
			begbid=findBegemot("bid",ql2.bid,ql2.bid_count,sec_code)
		end
		if ql2.offer_count~=0 and watch_list[sec_code].volume_offer~=0 then
			begoffer=findBegemot("offer",ql2.offer,ql2.offer_count,sec_code)
		end
		TradeBid(watch_list[sec_code].position_bid,begbid,begoffer,sec_code)
		TradeOffer(watch_list[sec_code].position_offer,begoffer,begbid,sec_code)
		watch_list.position_bid=begbid
		watch_list.position_offer=begoffer
	--end
	toLog(log,"OnQuote. "..(os.clock()-st))
end
function OnOrderDo(order)
		local st=os.clock()
		toLog(log,"OnOrder start. "..order.trans_id)
		if watch_list.open_order_bid.ordernum~=nil then
			toLog(log,"OpenOrderBidNUm="..watch_list.open_order_bid.ordernum)
		end
		if watch_list.open_order_offer.ordernum~=nil then
			toLog(log,"OpenOrderOfferNum="..watch_list.open_order_offer.ordernum)
		end
		if watch_list.close_order_bid.ordernum~=nil then
			toLog(log,"CloseOrderBidNUm="..watch_list.close_order_bid.ordernum)
		end
		if watch_list.close_order_offer.ordernum~=nil then
			toLog(log,"CloseOrderOfferNum="..watch_list.close_order_offer.ordernum)
		end
		if transactions[order.trans_id]=="openbid" then
			watch_list.open_order_bid={}
			watch_list.open_order_bid=order
			toLog(log,"OnOrder recieved new open bid. "..tostring(watch_list.open_order_bid))
			--toLog(log,watch_list[order.seccode].open_order_bid)
			--toLog(log,order)
			transactions[order.trans_id]=""
		elseif transactions[order.trans_id]=="closebid" then
			watch_list.close_order_bid={}
			watch_list.close_order_bid=order
			toLog(log,"OnOrder recieved new close bid. "..tostring(watch_list.close_order_bid))
			toLog(log,watch_list.close_order_bid)
			transactions[order.trans_id]=""
		elseif transactions[order.trans_id]=="closeoffer" then
			watch_list.close_order_offer={}
			watch_list.close_order_offer=order
			toLog(log,"OnOrder recieved new close offer. "..tostring(watch_list.close_order_offer))
			toLog(log,watch_list.close_order_offer)
			transactions[order.trans_id]=""
		elseif transactions[order.trans_id]=="openoffer" then
			watch_list.open_order_offer={}
			watch_list.open_order_offer=order
			toLog(log,"OnOrder recieved new open offer. "..tostring(watch_list.open_order_offer))
			--toLog(log,watch_list[order.seccode].open_order_offer)
			--toLog(log,order)
			transactions[order.trans_id]=""
		elseif order.ordernum==watch_list.open_order_bid.ordernum and order.balance~=order.qty then
			toLog(log,"Update on open bid order.")
			--toLog(log,order)
			watch_list.open_order_bid={}
			watch_list.open_order_bid=order
			if watch_list.close_order_bid.ordernum==nil and getPosFromTable(transactions,"closebid")<0 then
				toLog(log,"Open bid balance="..order.balance..". Send new close order")
				toLog(log,"Bid. Заявка исполнена. Выставляем заявку на закрытие")
				local pr=FindBidClosePrice(order.seccode,order.price)
				local trid,ms=sendLimit(order.class_code,order.seccode,"S",toPrice(order.seccode,pr),order.qty-order.balance,watch_list.account,watch_list.client_code)
				if trid~=nil then
					
					transactions[trid]="closebid"
				else
					toLog(log,ms)
				end
			elseif watch_list.close_order_bid.ordernum~=nil and watch_list.close_order_bid.qty<order.qty-order.balance and getPosFromTable(transactions,"closebid")<0 then
				toLog(log,"Open bid balance="..order.balance..". Modify close order="..watch_list.close_order_bid.ordernum)
				local trid,ms=moveOrder(1,watch_list.close_order_bid.ordernum,watch_list.close_order_bid.price,order.qty-order.balance)
				if trid~=nil then
					transactions[trid]="closebid"
				else
					toLog(log,ms)
				end
			end
		elseif order.ordernum==watch_list.open_order_offer.ordernum and order.balance~=order.qty then
			toLog(log,"Update on open offer order.")
			--toLog(log,order)
			watch_list.open_order_offer={}
			watch_list.open_order_offer=order
			if watch_list.close_order_offer.ordernum==nil  and getPosFromTable(transactions,"closeoffer")<0 then
				toLog(log,"Open offer balance="..order.balance..". Send new close order")
				toLog(log,"Offer. Заявка исполнена. Выставляем заявку на закрытие")
				local pr=FindOfferClosePrice(order.seccode,order.price)
				local trid,ms=sendLimit(order.class_code,order.seccode,"B",toPrice(order.seccode,pr),order.qty-order.balance,watch_list.account,watch_list.client_code)
				if trid~=nil then
					transactions[trid]="closeoffer"
				else
					toLog(log,ms)
				end
			elseif watch_list.close_order_offer.ordernum~=nil and watch_list.close_order_offer.qty<order.qty-order.balance  and getPosFromTable(transactions,"closeoffer")<0 then 
				toLog(log,"Open offer balance="..order.balance..". Modify close order="..watch_list.close_order_offer.ordernum)
				local trid,ms=moveOrder(1,watch_list.close_order_offer.ordernum,watch_list.close_order_offer.price,order.qty-order.balance)
				if trid~=nil then
					transactions[trid]="closeoffer"
				else
					toLog(log,ms)
				end
			end
		elseif order.ordernum==watch_list.close_order_bid.ordernum and order.balance==0 then
			toLog(log,"Close Bid full!")
			watch_list.close_order_bid={}
			watch_list.open_order_bid={}
		elseif order.ordernum==watch_list.close_order_offer.ordernum and order.balance==0 then
			toLog(log,"Close Offer full!")
			watch_list.close_order_offer={}
			watch_list.open_order_offer={}
		end
		toLog(log,"OnOrder end. "..(os.clock()-st))
	--end
end
function OnAllTradeDo(trade)
		local st=os.clock()
		toLog(log,"OnAllTrade start")
		toLog(log,trade)
		if watch_list.close_order_bid.ordernum~=nil 
		and watch_list.open_order_bid.price<trade.price 
		and getPosFromTable(transactions,"closebid")<0 then
			toLog(log,"AGHHH!!! Trade lower then our open price for BID")
			local ql2=getQuoteLevel2(trade.class_code,trade.seccode)
			local beg=findBegemot("bid",ql2.bid,ql2.bid_count,trade.seccode)
			if beg==0 then
				toLog(log,"2AGHHH!!! No begemots")
				local bask=tonumber(getParamEx(getSecurityInfo("",trade.seccode).class_code,trade.seccode,"OFFER").param_value)
				local trid,ms=moveOrder(0,watch_list.close_order_bid.ordernum,toPrice(trade.seccode,bask-watch_list.minstep))
				if trid~=nil then
					transactions[trid]="closebid"
				else
					toLog(log,ms)
				end
			else
				toLog(log,"Uhhh. Begemot still in glass "..beg)
				local bask=tonumber(getParamEx(getSecurityInfo("",trade.seccode).class_code,trade.seccode,"OFFER").param_value)
				local tp_level=beg+watch_list.tp*watch_list.minstep
				if tp_level<bask then
					local trid,ms=moveOrder(0,watch_list.close_order_bid.ordernum,toPrice(trade.seccode,bask-watch_list.minstep))
					if trid~=nil then
						transactions[trid]="closebid"
					else
						toLog(log,ms)
					end
				else
					local trid,ms=moveOrder(0,watch_list.close_order_bid.ordernum,toPrice(trade.seccode,tp_level))
					if trid~=nil then
						transactions[trid]="closebid"
					else
						toLog(log,ms)
					end
				end
			end
		elseif watch_list.close_order_offer.ordernum~=nil 
		and watch_list.open_order_offer.price>trade.price 
		and getPosFromTable(transactions,"closeoffer")<0 then
			toLog(log,"AGHHH!!! Trade upper then our open price for OFFER")
			local ql2=getQuoteLevel2(trade.class_code,trade.seccode)
			local beg=findBegemot("offer",ql2.offer,ql2.offer_count,trade.seccode)
			if beg==0 then
				toLog(log,"2AGHHH!!! No begemots")
				local bid=tonumber(getParamEx(getSecurityInfo("",trade.seccode).class_code,trade.seccode,"BID").param_value)
				local trid,ms=moveOrder(0,watch_list.close_order_offer.ordernum,toPrice(trade.seccode,bid+watch_list.minstep))
				if trid~=nil then
					transactions[trid]="closeoffer"
				else
					toLog(log,ms)
				end
			else
				toLog(log,"Uhhh. Begemot still in glass "..beg)
				local bid=tonumber(getParamEx(getSecurityInfo("",trade.seccode).class_code,trade.seccode,"BID").param_value)
				local tp_level=beg-watch_list.tp*watch_list.minstep
				if tp_level>bid then
					local trid,ms=moveOrder(0,watch_list.close_order_offer.ordernum,toPrice(trade.seccode,bid+watch_list.minstep))
					if trid~=nil then
						transactions[trid]="closeoffer"
					else
						toLog(log,ms)
					end
				else
					local trid,ms=moveOrder(0,watch_list.close_order_offer.ordernum,toPrice(trade.seccode,tp_level))
					if trid~=nil then
						transactions[trid]="closeoffer"
					else
						toLog(log,ms)
					end
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

function OnStop()
	toLog(log,"Stop button pressed!")
	is_run=false
end
function OnInit()
	log=getScriptPath().."\\"..log
	toLog(log,"Oninit callback")
	on_init=true
	is_run=true
end
function OnInitDo()
	local st=os.clock()

	toLog(log,"Begemot started. log="..log)
	is_run=getSettings(getScriptPath().."\\settings.txt")
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
	toLog(log,"OnInit ended. "..(os.clock()-st))
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