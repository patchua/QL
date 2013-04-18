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
  message ("Скрипт остановлен вручную", 2)
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
		if n_chart1==0 or n_chart1==nil then
			toLog(log,'Can`t get data from chart '..chart1)
			message('Не можем получить данные с графика '..chart1,1)
			is_run=false
			break
		end
		--обращаемся к длинному мувингу
		n_chart2 = getNumCandles(chart2)
		if n_chart2==0 or n_chart2==nil then
			toLog(log,'Can`t get data from chart '..chart2)
			message('Не можем получить данные с графика '..chart2,1)
			is_run=false
			break
		end
		--получаем предыдущее значение короткого мувинга
		short_mov1 = getCandlesByIndex(chart1,0,n_chart1-2,1)[0].close

		--получаем позапредыдущее значение короткого мувинга
		short_mov2 = getCandlesByIndex(chart1,0,n_chart2-3,1)[0].close
	  
		--получаем предыдущее значение длинного мувинга
		long_mov1 = getCandlesByIndex(chart2,0,n_chart2-2,1)[0].close

		--получаем позапредыдущее значение длинного   мувинга
		long_mov2 = getCandlesByIndex(chart2,0,n_chart2-3,1)[0].close

		--Детектор тренда
		if short_mov1>short_mov2 and long_mov1>long_mov2 then
			TREND_DETECTOR="Оба мувинга растут. Рынок быков" --выводим переменную TREND_DETECTOR в таблицу КВИКа.
		elseif short_mov1<short_mov2 and long_mov1<long_mov2 then
			TREND_DETECTOR="Оба мувинга падают. Рынок медведей" --выводим переменную TREND_DETECTOR в таблицу КВИКа.
		else
			TREND_DETECTOR="Нет выраженного тренда"
		end
	
		--Генерация сигналов.

		--Золотой крест
		if short_mov1>long_mov1 and short_mov2<long_mov2 then
			iup.Message('Новый сигнал!','ЗОЛОТОЙ КРЕСТ')	
			toLog (log, "Golden Cross detected")
			SIGNAL="GOLDEN CROSS" --выводим в таблицу КВИКа.
		--Мёртвый крест
		elseif short_mov1<long_mov1 and short_mov2>long_mov2 then
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
	iup.Close()
end