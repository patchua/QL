require"QL"
--require"luaxml"
is_run=false
log="spreader.txt"
settings={}
--params
security="UXU2S"
class="BQUOTEFUT"
work_spread=10
wait_slippage=15
alert_slippage=30
minprofit=5
clc="game998"
account="game998"
bidEnable=true
askEnable=false
volume=1
--var
bid_order={}
bid_status=""
bid_open_price=0
bid_bad=false
ask_bad=false
ask_open_price=0
ask_status=""
ask_order={}
transactions={}

function OnInit(script_path)
	--log=script_path.."\\"..log
	toLog(log,"OnInit start. path="..script_path)
	--toLog(log,"set path="..script_path.."\\settings.xml")
	--[[
	settings=xml.load("settings.xml")
	if settings==nil then
		toLog(log,"Can`t open settings file!")
		return
	end
	security=settings:find("security").value
	class=settings:find("class").value
	work_spread=settings:find("work_spread").value
	wait_slippage=settings:find("wait_slippage").value
	alert_slippage=settings:find("alert_slippage").value
	minprofit=settings:find("minprofit").value
	clc=settings:find("clc").value
	account=settings:find("account").value
	volume=settings:find("volume").value
	if settings:find("bidEnable").value==1 then bidEnable=true else bidEnable=false end
	if settings:find("askEnable").value==1 then askEnable=true else askEnable=false end
	toLog(log,"Settings loaded sucessfully.")
	toLog(log,settings)
	--]]

	step=getParamEx(class,security,"SEC_PRICE_STEP").param_value
	is_run=true
	toLog(log,"Start main. step="..step)
end

function OnStop()
	toLog(log,"Stop pressed!")
	if bidEnable and bid_order~=nil then _,_=killOrder(bid_order.ordernum) end
	if askEnable and ask_order~=nil then _,_=killOrder(ask_order.ordernum) end
	is_run=false
end

function OnQuote(pclass,psecurity)
	if pclass~=class or psecurity~=security then return end
	local qt2=getQuoteLevel2(pclass,psecurity)
	--if new_bid==bbid and new_ask==bask then return else bbid,bask=new_bid,new_ask end
	--toLog(log,"Param changed. BBid="..bbid.." BAsk="..bask)
	if bidEnable and askEnable then
		toLog(log,"BID+ASK")
		workboth(qt2)
	elseif bidEnable then
		toLog(log,"BID only")
		workbid(qt2)
	elseif askEnable() then
		toLog(log,"ASK only")
		workask(qt2)
	else
		toLog(log,"Nothing to do")
		is_run=false
	end
	toLog(log,"OnQuote end. is_run="..tostring(is_run))
end

function workbid(quotes)
	toLog(log,"Workbid started. status="..bid_status)
	local sbid=tonumber(quotes.bid[quotes.bid_count-2].price)
	local sask=tonumber(quotes.offer[2].price)
	local bask=tonumber(quotes.offer[1].price)
	local baskvol=tonumber(quotes.offer[1].quantity)
	local bbid=tonumber(quotes.bid[quotes.bid_count-1].price)
	local bbidvol=tonumber(quotes.bid[quotes.bid_count-1].quantity)
	local spread=bask-bbid
	toLog(log,"sbid="..sbid.." bbid="..bbid.." bbidvol="..bbidvol.." bask="..bask.." sask="..sask.." baskvol="..baskvol)
	if bid_status=="" and spread>(work_spread-1)*step then
		-- no bid, can send
		toLog(log,"Can send bid for open. Spread="..spread..class..security.."B"..toPrice(security,bbid+step)..volume..account..clc.."openbid")
		local id,ms=sendLimit(class,security,"B",toPrice(security,bbid+step),volume,account,clc,"openbid")
		if id~=nil then
			transactions[id]="bid"
			bid_status="waitopen"
		end
		toLog(log,ms)
	elseif bid_status=="open" and spread<work_spread*step then
		--have bid, tiny spread, move farther
		toLog(log,"Move bid farther. Our_price="..bid_order.price.." spread="..spread)
		local id,ms=moveOrder(0,bid_order.ordernum,toPrice(security,bbid-wait_slippage*step))
		if id~=nil then
			transactions[id]="bid"
			bid_status="waitremote"
		end
		toLog(log,ms)
	elseif bid_status=="open" and bid_order.price<bbid then
		if bask-bbid>(work_spread-1)*step then
			-- move bid to be first
			toLog(log,"Move bid to be first. Our_price="..bid_order.price.." BBid="..bbid)
			local id,ms=moveOrder(0,bid_order.ordernum,toPrice(security,bbid+step))
			if id~=nil then
				transactions[id]="bid"
				bid_status="waitopen"
			end
			toLog(log,ms)
		else
			--need to move bid but if we do this, spread wolud be tiny. move farther
			toLog(log,"Move bid farther. Our_price="..bid_order.price.." spread="..(bask-bbid))
			local id,ms=moveOrder(0,bid_order.ordernum,toPrice(security,bbid-wait_slippage*step))
			if id~=nil then
				transactions[id]="bid"
				bid_status="waitremote"
			end
			toLog(log,ms)
		end
	elseif bid_status=="open" and bid_order.price>sbid+1 and bbidvol==volume then
		-- have bid, can move to better position
		toLog(log,"Move open bid closer to second. Our_price="..bid_order.price.." SBid="..sbid.." BBidVol="..bbidvol)
		local id,ms=moveOrder(0,bid_order.ordernum,toPrice(security,sbid+1))
		if id~=nil then
			transactions[id]="bid"
			bid_status="waitopen"
		end
		toLog(log,ms)
	elseif bid_status=="remote" and spread>(work_spread-1)*step then
		--have remote bid, spread became good,move to be first and wait for open
		toLog(log,"Move remote bid to open position. Our_price="..bid_order.price.." spread="..spread)
		local id,ms=moveOrder(0,bid_order.opennum,toPrice(security,bbid+step))
		if id~=nil then
			transactions[id]="bid"
			bid_status="waitopen"
		end
		toLog(log,ms)
	elseif bid_status=="close" and (bid_bad or bask-step>bid_open_price+minprofit*step) and bask<bid_order.price then
		-- have close on bid, found better ask
		toLog(log,"Move close bid lower. BAsk="..bask.." Bad="..tostring(bid_bad).." Our_price="..bid_order.price)
		local id,ms=moveOrder(0,bid_order.ordernum,toPrice(security,bask-step))
		if id~=nil then
			transactions[id]="bid"
			bid_staus="waitclose"
		end
		toLog(log,ms)
	elseif bid_status=="close" and sask-1>bid_order.price and bask==volume then
		--can move close to better position
		toLog(log,"MOve close bid to better position. Our_price="..bid_order.price.." SAsk="..sask.." BAskVol="..baskvol)
		local id,ms=moveOrder(0,bid_order.ordernum,toPrice(security,bask-step))
		if id~=nil then
			tramsactions[id]="bid"
			bid_status="waitclose"
		end
		toLog(log,ms)
	else
		--toLog(log,"Nothing to do. Bask="..bask.." Sask="..sask.." Bbid="..bbid.." sbid="..sbid.." bid_status="..bid_status)
	end
	toLog(log,"Workbid ended.")
end

function OnAllTrade(trade)
	if trade.seccode~="UXH3" then return end -- chenge after tests
	toLog(log,"New AllTrade price="..trade.price)
	if (bid_status=="close" or bid_status=="waitclose") and trade.price<bid_open_price-alert_slippage*step then bid_bad=true end
	if (ask_status=="close" or ask_status=="waitclose") and trade.price>ask_open_price+alert_slippage*step then ask_bad=true end
end

function OnOrder(order)
	if transactions[order.trans_id]=="bid" then
		toLog(log,"New bid order received.")
		bid_order={}
		bid_order=order
		bid_status=string.gsub(bid_status,"wait","")
		if order.balance==0 then
			toLog(log,bid_status.." order filled!. Balane="..order.balance)
			if bid_status=="open" then
				toLog(log,"Send close order")
				bid_open_price=order.price
				bid_bad=false
				local bask=getParamEx(class,security,"OFFER").param_value
				local id,ms=sendLimit(class,security,"S",toPrice(security,bask-step),volume,account,clc,"closebid")
				if id~=nil then
					transactions[id]="bid"
					bid_status="waitclose"
				end
				toLog(log,ms)
			else
				toLog(log,"Start new cycle.")
				bid_bad=false
				bid_open_price=0
				bid_order={}
				bid_status=""
			end
		end
	elseif transactions[order.trans_id]=="ask" then
		toLog(log,"New ask order received.")
		ask_order={}
		ask_order=order
		ask_status=string.gsub(ask_status,"wait","")
		if order.balance==0 then
			toLog(log,ask_status.." order filled!. Balane="..order.balance)
			if ask_status=="open" then
				toLog(log,"Send close order")
				ask_open_price=order.price
				ask_bad=false
				local bbid=getParamEx(class,security,"BID").param_value
				local id,ms=sendLimit(class,security,"B",toPrice(security,bbid+step),volume,account,clc,"closeask")
				if id~=nil then
					transactions[id]="ask"
					ask_status="waitclose"
				end
				toLog(log,ms)
			else
				toLog(log,"Start new cycle.")
				ask_bad=false
				ask_open_price=0
				ask_order={}
				ask_status=""
			end
		end
	else
		toLog(log,"____ some shit on OnOrder()_____")
		toLog(log,order)
		toLog(log,"________________________________")
	end
end

function main()
	while is_run do
		sleep(50)
	end
end