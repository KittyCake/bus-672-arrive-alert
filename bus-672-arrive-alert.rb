# # 寫一個 script ，可以在 672 往大鵬新城方向的公車，
# # 到達 博仁醫院 前 3~5 站時發出通知 (語言/通知方法不限)

# 672 往大鵬新城 (direction: 1)
# 起站：三民路 訖站：中正環河路口

# 沒有註冊會員，一天只能打 50 次 API
APP_ID = 'FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF'
APP_KEY = 'FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF'

require 'httparty'

class BusData
  include HTTParty
  base_uri 'https://ptx.transportdata.tw/MOTC/v2'
  format :json
  @current_timestamp = Time.now.utc.strftime('%a, %d %b %Y %T GMT')

  headers(
    'Content-Type'  => 'application/json',
    'Accept'        => 'application/json',
    'X-Date'        => ->{ @current_timestamp },
    'Authorization' => ->{ authorization_header },
  )

  class << self
    def authorization_header
      hmac = Base64.strict_encode64(
        OpenSSL::HMAC.digest('sha1', APP_KEY, "x-date: #{@current_timestamp}")
      )
      return %(hmac username="#{APP_ID}", algorithm="hmac-sha1", headers="x-date", signature="#{hmac}")
    end
  end

  # 指定路線的所有站牌資訊
  def bus_stop_list(city: '', route_name: '', direction: [0, 1])
    response = self.class.get(
      "/Bus/DisplayStopOfRoute/City/#{city}/#{route_name}"
    ).parsed_response
    # 因為有區間車的可能，所以在篩選一次 route name，
    # 如果要涵括區間車，就不用這一段
    response.select do |stop_info|
      stop_info['RouteName']['Zh_tw'] == route_name &&
      direction.include?(stop_info['Direction'])
    end
  end

  # 指定路線的各台公車靠站資訊
  def real_time_data(city: '', route_name: '')
    self.class.get("/Bus/RealTimeNearStop/City/#{city}/#{route_name}").parsed_response
  end
end

city = 'Taipei'
route_name = '672'
direction = 1 # 往大鵬新城
stop_name = '博仁醫院'

stops = BusData.new.bus_stop_list(
  city: city, route_name: route_name, direction: [direction]
)[0]['Stops']

# 取得博仁醫院的站序
hospital_sequence = stops.find do |stop|
  stop['StopName']['Zh_tw'] == stop_name
end['StopSequence']

# 取得博仁醫院前 3~5 站的站序
sequences_to_alert = [*hospital_sequence-5..hospital_sequence-3]

# 在 develop 怕忘記退出，隨意設定一個小時後程式自動停止
end_time = Time.now + 60*60

while Time.now < end_time do
  real_time_672_datas = BusData.new.real_time_data(city: city, route_name: route_name)

  alert_user = real_time_672_datas.select do |data| 
    data['Direction'] == direction &&
    data['RouteName']['Zh_tw'] == route_name &&
    data['BusStatus'] == 0 && # 正常營運
    sequences_to_alert.include?(data['StopSequence'])
  end

  if !alert_user.empty?
    puts '公車要來囉！'
  else
    puts '公車還沒來'
  end

  # 每五分鐘檢查一次，公車沒開這麼快
  sleep(60*5)
end