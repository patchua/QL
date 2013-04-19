require"QL"
require"iuplua"

log="moving_signals.log"
--идентификаторы графиков
chart1="short_mov"
chart2="long_mov"

is_run = true

function OnStop()
  is_run = false
  toLog(log,'OnStop. Script finished manually')
  -- уничтожаем таблицу Квик
  t:delete()
end

function main()
	log=getScriptPath()..'\\'..log
	toLog(log,"Start main")
	--создаем таблицу Квик
	t=QTable:new()
	-- добавляем 2 столбца
	t:AddColumn("TREND DETECTOR",QTABLE_STRING_TYPE,45)
	t:AddColumn("SIGNAL",QTABLE_STRING_TYPE,30)
	-- назначаем название для таблицы
	t:SetCaption('Moving Signals')
	-- показываем таблицу
	t:Show()
	-- добавляем пустую строку
	line=t:AddLine()

	while is_run do
		--получаем значения индикаторов

		--обращаемся к короткому мувингу
		n_chart1 = getNumCandles (chart1)
		toLog(log,'chart1 num='..n_chart1)
		if not isChartExist(chart1) then
			toLog(log,'Can`t get data from chart '..chart1)
			message('Не можем получить данные с графика '..chart1,1)
			is_run=false
			break
		end
		--обращаемся к длинному мувингу
		n_chart2 = getNumCandles(chart2)
		if not isChartExist(chart2) then
			toLog(log,'Can`t get data from chart '..chart2)
			message('Не можем получить данные с графика '..chart2,1)
			is_run=false
			break
		end
		
		--Детектор тренда
		if turnUp(chart1) and turnUp(chart2) then
			TREND_DETECTOR="Оба мувинга растут. Рынок быков" --выводим переменную TREND_DETECTOR в таблицу КВИКа.
		elseif turnDown(chart1) and turnDown(chart2) then
			TREND_DETECTOR="Оба мувинга падают. Рынок медведей" --выводим переменную TREND_DETECTOR в таблицу КВИКа.
		else
			TREND_DETECTOR="Нет выраженного тренда"
		end
	
		--Генерация сигналов.

		--Золотой крест
		if crossOver(n_chart1-1,chart1,chart2) then
			iup.Message('Новый сигнал!','ЗОЛОТОЙ КРЕСТ')	
			toLog (log, "Golden Cross detected")
			SIGNAL="GOLDEN CROSS" --выводим в таблицу КВИКа.
		--Мёртвый крест
		elseif crossUnder(n_chart1-1,chart1,chart2) then
			iup.Message('Новый сигнал!','МЁРТВЫЙ КРЕСТ')	
			toLog (log, "Dead Cross detected")
			SIGNAL="DEAD CROSS" --выводим в таблицу КВИКа.
		else
			SIGNAL="NO SIGNAL" --выводим в таблицу КВИКа.
		end
		-- заполняем значения для ячеек таблицы
		t:SetValue(line,"TREND DETECTOR",TREND_DETECTOR)
		t:SetValue(line,"SIGNAL",SIGNAL)

		sleep(1000)
	end
	toLog(log,"Main ended")
	iup.ExitLoop()
	iup.Close()
end