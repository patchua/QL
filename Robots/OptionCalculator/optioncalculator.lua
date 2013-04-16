require'QL'
require'iuplua'
log='OptionCalculator.log'
is_run=false
futures_holding={}
on_param={}
data={}
portfolios_list={}
gui={}
last_calc_time=0
period=10
riskFreeRate=0
yearLength=365
FUTCLASSES='SPBFUT,FUTUX'
OPRCLASSES='SPBOPT,OPTUX'
-- GUI
mainbox=iup.vbox{}
dialog=iup.dialog{mainbox; title="Option Calculator", size="THIRDxTHIRD"} 


function dialog:close_cb()
	toLog(log,'Close dialog button pressed')
	is_run=false
end
function OnClose()
	toLog(log,'Close script button pressed')
	is_run=false
end
function normalDistr(z)
	local b1 =  0.31938153; 
    local b2 = -0.356563782; 
    local b3 =  1.781477937;
    local b4 = -1.821255978;
    local b5 =  1.330274429; 
    local p  =  0.2316419; 
    local c2 =  0.3989423; 

    if (z >  6.0) then return 1 end
    if (z < -6.0) then return 0 end
    local a = math.abs(z)
    local t = 1.0/(1.0+a*p)
    local b = c2*math.exp((-z)*(z/2.0))
    local n = ((((b5*t+b4)*t+b3)*t+b2)*t+b1)*t
    n = 1.0-b*n
    if ( z < 0.0 ) then n = 1.0 - n end 
    return n 
end
function normalDistrDensity(z)
	return math.exp(-0.5*z*z)/math.sqrt(2*math.pi)
end
-- different functions for greeks
function delta(opt_type,settleprice,strike,volatility,pdaystomate,risk_free)
	local d1=(math.log(settleprice/strike)+volatility*volatility*0.5*pdaystomate)/(volatility*math.sqrt(pdaystomate))
	if otp_type=="Call" then
		return math.exp(-1*risk_free*pdaystomate)*normalDistr(d1)
	else
		return -1*math.exp(-1*risk_free*pdaystomate)*normalDistr(-1*d1)
	end
end
function gamma(settleprice,strike,volatility,pdaystomate,risk_free)
	local d1=(math.log(settleprice/strike)+volatility*volatility*0.5*pdaystomate)/(volatility*math.sqrt(pdaystomate))
	return normalDistrDensity(d1)*math.exp(-1*risk_free*pdaystomate)/(settleprice*volatility*math.sqrt(pdaystomate))
end
function theta(opt_type,settleprice,strike,volatility,pdaystomate,risk_free)
	local d1=(math.log(settleprice/strike)+volatility*volatility*0.5*pdaystomate)/(volatility*math.sqrt(pdaystomate))
	local temp=settleprice*math.exp(-1*risk_free*pdaystomate)
	local d2=d1-volatility*math.sqrt(pdaystomate)
	if opt_type=='Call' then
		return -1*(temp*normalDistrDensity(d1)*volatility)/(2*math.sqrt(pdaystomate))+risk_free*temp*normalDistr(d1)-risk_free*strike*temp*normalDistr(d2)
	else
		return -1*(temp*normalDistrDensity(d1)*volatility)/(2*math.sqrt(pdaystomate))-risk_free*temp*normalDistr(-1*d1)+risk_free*strike*temp*normalDistr(-1*d2)
	end
end
function vega(settleprice,strike,volatility,pdaystomate,risk_free)
	local d1=(math.log(settleprice/strike)+volatility*volatility*0.5*pdaystomate)/(volatility*math.sqrt(pdaystomate))
	return settleprice*normalDistrDensity(d1)*math.exp(-1*risk_free*pdaystomate)*math.sqrt(pdaystomate)
end
function rho(opt_type,settleprice,strike,volatility,pdaystomate,risk_free)
	local d1=(math.log(settleprice/strike)+volatility*volatility*0.5*pdaystomate)/(volatility*math.sqrt(pdaystomate))
	local d2=d1-volatility*math.sqrt(pdaystomate)
	if opt_type=='Call' then
		return pdaystomate*strike*math.exp(-1*risk_free*pdaystomate)*normalDistr(d2)
	else
		return -1*pdaystomate*strike*math.exp(-1*risk_free*pdaystomate)*normalDistr(-1*d2)
	end
end
function phi(opt_type,settleprice,strike,volatility,pdaystomate,risk_free)
	local d1=(math.log(settleprice/strike)+volatility*volatility*0.5*pdaystomate)/(volatility*math.sqrt(pdaystomate))
	if opt_type=='Call' then
		return -1*pdaystomate*settleprice*math.exp(-1*risk_free*pdaystomate)*normalDistr(d1)
	else
		return pdaystomate*settleprice*math.exp(-1*risk_free*pdaystomate)*normalDistr(-1*d1)
	end
end
function zeta(opt_type,settleprice,strike,volatility,pdaystomate,risk_free)
	local d1=(math.log(settleprice/strike)+volatility*volatility*0.5*pdaystomate)/(volatility*math.sqrt(pdaystomate))
	local d2=d1-volatility*math.sqrt(pdaystomate)
	if opt_type=='Call' then
		return normalDistr(d2)
	else
		return normalDistr(-1*d2)
	end
end
function allGreeks(opt_type,settleprice,strike,volatility,pdaystomate,risk_free)
	local d1=(math.log(settleprice/strike)+volatility*volatility*0.5*pdaystomate)/(volatility*math.sqrt(pdaystomate))
	local d2=d1-volatility*math.sqrt(pdaystomate)
	local t={}
	if otp_type=="Call" then
		t.delta=math.exp(-1*risk_free*pdaystomate)*normalDistr(d1)

	else
		t.delta=-1*math.exp(-1*risk_free*pdaystomate)*normalDistr(-1*d1)
	end
end
--quik callbacks
function OnFuturesClientHolding(hold)
	if is_run and hold~=nil then
		toLog(log,'New holding update')
		table.insert(futures_holding,hold)
	end
end
-- our functions
function OnInitDo()
	log=getScriptPath()..'\\'..log
	local i,row
	toLog(log,getNumberOf('futures_client_holding'))
	for i=0,getNumberOf('futures_client_holding') do
		row=getItem('futures_client_holding',i)
		if row.trdaccid~='' and row.type==0 then
			updatePortfoliosList(row)
			toLog(log,"Account "..row.trdaccid.." added to data")
		end
	end
	updateGUI()
	toLog(log,gui)
	return true
end
function updatePortfoliosList(position)
	toLog(log,'Update portfolio list with position '..position.seccode)
	local base=''
	local pl=portfolios_list
	local class=getSecurityInfo('',position.seccode).class_code
	if string.find(FUTCLASSES,class)~=nil then
		toLog(log,"Futures position")
		base=position.seccode
	else
		toLog(log,'Option position')
		base,err=getParam(position.seccode,'optionbase')
	end
	if pl[position.trdaccid]==nil then
		toLog(log,'First position for account '..position.trdaccid..'. Create new node. Base='..base)
		pl[position.trdaccid]={}
		pl[position.trdaccid][base]={}
		pl[position.trdaccid][base][position.seccode]=position
		pl[position.trdaccid][base].delta=0
		pl[position.trdaccid][base].gamma=0
		pl[position.trdaccid][base].vega=0
		pl[position.trdaccid][base].theta=0
		pl[position.trdaccid][base].rho=0
		pl[position.trdaccid][base].phi=0
		pl[position.trdaccid][base].zeta=0
		return true
	end
	if pl[position.trdaccid][base]==nil then
		toLog(log,'First position for base contract '..base..'. Create new node. Account '..position.trdaccid)
		pl[position.trdaccid][base]={}
		pl[position.trdaccid][base][position.seccode]=position
		pl[position.trdaccid][base].delta=0
		pl[position.trdaccid][base].gamma=0
		pl[position.trdaccid][base].vega=0
		pl[position.trdaccid][base].theta=0
		pl[position.trdaccid][base].rho=0
		pl[position.trdaccid][base].phi=0
		pl[position.trdaccid][base].zeta=0
		return true
	end
	if pl[position.trdaccid][base][position.seccode]==nil then
		toLog(log,'New position for account '..position.trdaccid..' Base '..base..'. Add new node. Sec= '..position.seccode)
		pl[position.trdaccid][base][position.seccode]=position
		return true
	end
	if pl[position.trdaccid][base][position.seccode].totalnet~=position.totalnet then
		toLog(log,'Update quantity to '..position.totalnet..' for Acc='..position.trdaccid..' Base='..base..' Sec='..position.seccode)
		pl[position.trdaccid][base][position.seccode]=position
		return true
	end
	toLog(log,'Update portfolio list ended')
	return false
end
--[[
function CalculatePortfolioGreeks(account,base)
	local function create_empty(account,base_code)
		local d=data[account][base_code]
		d.delta=0
		d.gamma=0
		d.theta=0
		d.vega=0
		d.rho=0
		d.phi=0
		d.zeta=0
	end
	local function create_new(account,base_code)
		toLog(log,'No '..base_code..' contract in data table')
		data[account][base_code]={} 
		create_empty(account,base_code)
		local hbox
		local d=data[account][base_code]
		acc_lbl=iup.label{title=account,expand='YES'}
		sec_lbl=iup.label{title=base_code,expand='YES'}
		d.d_lbl=iup.label{title='0',expand='YES'}
		d.g_lbl=iup.label{title='0',expand='YES'}
		d.v_lbl=iup.label{title='0',expand='YES'}
		d.t_lbl=iup.label{title='0',expand='YES'}
		hbox=iup.hbox{d.acc_lbl,d.sec_lbl,d.d_lbl,d.g_lbl,d.v_lbl,d.t_lbl}
		iup.Map(iup.Append(mainbox,hbox))
		iup.Refresh(mainbox)
		toLog(log,"New interface element sucessfully mapped")
	end
	if account==nil then toLog(log,"nil account") return end
	toLog(log,"Start calculating portfolio greeks for account "..account)
	local i,base,class,sprice,volat,pdtm,strike,type
	for k,v in pairs(data[account]) do
		create_empty(k)
	end
	for i=0,getNumberOf('futures_client_holding') do
		row=getItem('futures_client_holding',i)
		if row.trdaccid==account and row.totalnet~=0 and row.firmid=='FOUX' then 
			toLog(log,row)
			class=getSecurityInfo('',row.seccode).class_code
			if string.find('SPBFUT,FUTUX',class)~=nil then
				toLog(log,'Futures position')
				if data[account][row.seccode]==nil then 
					crete_new(account,row.seccode)
				end
				data[account][row.seccode].delta=data[account][row.seccode].delta+row.totalnet
				data[account][row.seccode].d_lbl.title=data[account][row.seccode].delta
			else
				toLog(log,"Option position")
				base=getParamEx(class,row.seccode,'optionbase').param_value
				if data[account][base]==nil then 
					crete_new(account,base)
				end
				local dat=data[account][base]
				type=getParamEx(class,row.seccode,'optiontype').param_value
				volat=getParamEx(class,row.seccode,'volatility').param_value/100
				strike=getParamEx(class,row.seccode,'strike').param_value
				sprice=getParamEx(class,row.seccode,'last').param_value
				pdtm=getParamEx(class,row.seccode,'DAYS_TO_MAT_DATE').param_value/yearLength
				toLog(log,row.seccode.." Position Base="..base.." type="..type..' BasePrice='..last..' Volat='..volat..' Strike='..strike..' pdtm='..pdtm)
				dat.delta=dat.delta+row.totalnet*delta(type,sprice,strike,volat,pdtm,riskFreeRate)
				dat.gamma=dat.gamma+row.totalnet*gamma(sprice,strike,volat,pdtm,riskFreeRate)
				dat.vega=dat.vega+row.totalnet*vega(sprice,strike,volat,pdtm,riskFreeRate)
				dat.theta=dat.theta+row.totalnet*theta(type,sprice,strike,volat,pdtm,riskFreeRate)
				dat.rho=dat.rho+row.totalnet*rho(type,sprice,strike,volat,pdtm,riskFreeRate)
				dat.phi=dat.phi+row.totalnet*phi(type,sprice,strike,volat,pdtm,riskFreeRate)
				dat.zeta=dat.zeta+row.totalnet*zeta(type,sprice,strike,volat,pdtm,riskFreeRate)
				dat.d_lbl.title=dat.delta
				dat.g_lbl.title=dat.gamma
				dat.t_lbl.title=dat.theta
				dat.v_lbl.title=dat.vega
				toLog(log,'Position calculated. New greeks')
				toLog(log,dat)
				toLog(log,'----------')
			end
		end
	end
	toLog(log,'Calculation ended.')
	toLog(log,data[account])
	toLog(log,'------------------')
end
]]
function calculateGreeks(acc,base)
	toLog(log,'calculations started')
	local pl=portfolios_list[acc][base]
	local class=''
	local opttype,volat,stryke,sprice,pdtm
	pl.delta=0
	pl.gamm=0
	pl.vega=0
	pl.theta=0
	pl.rho=0
	pl.phi=0
	pl.zeta=0
	for k,v in pairs(pl) do
		if type(v)=='table' and v.totalnet~=0 then
			class=getSecurityInfo('',k).class_code
			if string.find(FUTCLASSES,class)~=nil then
				toLog(log,'Futures position ')
				pl.delta=pl.delta+v.totalnet
			else
				opttype=getParam(k,'optiontype')
				volat=getParam(k,'volatility')/100
				strike=getParam(k,'strike')
				sprice=getParam(base,'last')
				pdtm=getParam(k,'DAYS_TO_MAT_DATE')/yearLength
				toLog(log,k.." Position Base="..base.." type="..opttype..' BasePrice='..sprice..' Volat='..volat..' Strike='..strike..' pdtm='..pdtm)
				pl.delta=pl.delta+v.totalnet*delta(opttype,sprice,strike,volat,pdtm,riskFreeRate)
				pl.gamma=pl.gamma+v.totalnet*gamma(sprice,strike,volat,pdtm,riskFreeRate)
				pl.vega=pl.vega+v.totalnet*vega(sprice,strike,volat,pdtm,riskFreeRate)
				pl.theta=pl.theta+v.totalnet*theta(opttype,sprice,strike,volat,pdtm,riskFreeRate)
				pl.rho=pl.rho+v.totalnet*rho(opttype,sprice,strike,volat,pdtm,riskFreeRate)
				pl.phi=pl.phi+v.totalnet*phi(opttype,sprice,strike,volat,pdtm,riskFreeRate)
				pl.zeta=pl.zeta+v.totalnet*zeta(opttype,sprice,strike,volat,pdtm,riskFreeRate)
			end
		end
	end
end
function createGUIelement(acc,base)
	toLog(log,'Create GUI element '..acc..' '..base)
	local t=gui[acc][base]
	t.acc_lbl=iup.label{title=acc,expand="YES"}
	t.base_lbl=iup.label{title=base,expand="YES"}
	t.delta_lbl=iup.label{title='delta=',expand="YES"}
	t.gamma_lbl=iup.label{title='gamma=',expand="YES"}
	t.theta_lbl=iup.label{title='theta=',expand="YES"}
	t.vega_lbl=iup.label{title='vega=',expand="YES"}
	t.rho_lbl=iup.label{title='rho=',expand="YES"}
	t.phi_lbl=iup.label{title='phi=',expand="YES"}
	t.zeta_lbl=iup.label{title='zeta=',expand="YES"}
	hbox=iup.hbox{t.acc_lbl,t.base_lbl,t.delta_lbl,t.gamma_lbl,t.theta_lbl,t.vega_lbl,t.rho_lbl,t.phi_lbl,t.zeta_lbl}
	if iup.Append(mainbox,hbox)==nil then toLog(log,"Can`t append interface element") return nil end
	--if iup.MainLoopLevel()~=0 then
		--toLog(log,'GUI launched. need to call Map&Refresh')
		iup.Map(hbox)
		iup.Refresh(mainbox)
	--end
	return t
end
function updateGUI()
	toLog(log,'Update GUI started')
	local pl=portfolios_list
	for k,v in pairs(pl) do
		for k1,v1 in pairs(v) do
			if gui[k]==nil then
				gui[k]={}
				gui[k][k1]={}
				gui[k][k1]=createGUIelement(k,k1)
			elseif gui[k][k1]==nil then
				gui[k][k1]={}
				gui[k][k1]=createGUIelement(k,k1)
			else
				toLog(log,'Update controls')
				gui[k][k1].delta_lbl.title='delta='..string.format('%.2f',v1.delta)
				gui[k][k1].gamma_lbl.title='gamma='..string.format('%.2f',v1.gamma)
				gui[k][k1].theta_lbl.title='theta='..string.format('%.2f',v1.theta)
				gui[k][k1].vega_lbl.title='vega='..string.format('%.2f',v1.vega)
				gui[k][k1].rho_lbl.title='rho='..string.format('%.2f',v1.rho)
				gui[k][k1].phi_lbl.title='phi='..string.format('%.2f',v1.phi)
				gui[k][k1].zeta_lbl.title='zeta='..string.format('%.2f',v1.zeta)
			end
		end
	end
	toLog(log,'Update GUI ended')
end
--
function main()
	is_run=OnInitDo()
	if is_run then
		toLog(log,'Main start')
		dialog:show()
	end
	while is_run do
		-- calculation`s with sleep. not callbacks
		if getSTime()>last_calc_time+period and portfolios_list~=nil then
			toLog(log,'Time to calculate new values')
			for k,v in pairs(portfolios_list) do
				for k1,v1 in pairs(v) do
					toLog(log,'Start to calclate greeks for '..k..' '..k1)
					calculateGreeks(k,k1)
				end
			end
			updateGUI()
			last_calc_time=getSTime()
		elseif #futures_holding~=0 then
			local res=false
			for i=0,#futures_holding do
				local t=table.remove(futures_holding,1)
				if t~=nil then local r=updatePortfoliosList(t) res=res or r else toLog(log,'nil on holding remove') end
			end
			if res then updateGUI() end
		else
			iup.LoopStep()
			sleep(1)
		end
	end
	dialog:destroy()
	iup.ExitLoop()
	iup.Close()
	toLog(log,'Main end')
end