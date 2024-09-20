require 'json'
require 'shellwords'
require 'bigdecimal'

WALLETS = ["test", "test2"]
DATADIR = "/home/jjy/bitcoin-testnet"

def bitcoin_cmd(cmd)
  puts "Exec #{cmd} =>"
  `bitcoin-cli -datadir=#{DATADIR} -testnet #{cmd}`
end

def load_wallet(name)
  puts "Load wallet #{name}"
  WALLETS.each do |w|
    if w == name 
      bitcoin_cmd("loadwallet #{w}")
    else
      bitcoin_cmd("unloadwallet #{w}")
    end
  end
  wallets = JSON.parse bitcoin_cmd("listwallets")
  if wallets != [name]
    raise "Wrong wallets", wallets
  end
end

def sat_to_btc amt
  amt.to_f / (10 ** 8)
end

def decode_psbt psbt
  JSON.parse bitcoin_cmd("decodepsbt #{psbt}"), decimal_class: BigDecimal
end

def fund_0 addr, sats
  puts "Fund 0"
  load_wallet WALLETS[0]
  amt = sat_to_btc sats
  bitcoin_cmd "walletcreatefundedpsbt [] '[{\"#{addr}\": #{amt}}]'"
end

def fund_1 addr, sats, psbt
  puts "Fund 1"
  load_wallet WALLETS[1]
  amt = sat_to_btc sats

  solving_data = {"pubkeys": [], "descriptors": []}

  # find inputs from psbt
  inputs = psbt["tx"]["vin"].map do |vin|
    {"txid": vin["txid"], "vout": vin["vout"], "sequence": vin["sequence"], "weight": 500 }
  end

  outputs = [{"#{addr}": amt}]
  psbt["tx"]["vout"].each do |vout|
    vout_addr = vout["scriptPubKey"]["address"]
    if vout_addr.downcase != addr.downcase
      #witness_v1_taproot
      #solving_data[:"pubkeys"] << vout["scriptPubKey"]["hex"]
      solving_data[:"descriptors"] << vout["scriptPubKey"]["desc"]
      outputs << {"#{vout_addr}": vout["value"]}
    end
  end

  #solving_data[:"pubkeys"] << psbt["bip32_derivs"]["pubkey"]

  options = {"add_inputs": true, "solving_data": solving_data}

  bitcoin_cmd "walletcreatefundedpsbt #{Shellwords.escape inputs.to_json} #{Shellwords.escape outputs.to_json} 0 #{ Shellwords.escape options.to_json}"
end

# start
def run
  addr = ARGV[0]
  if !addr || addr.empty?
    puts "Need funding addr in argv 0"
    return
  end
  puts "Funding to #{addr}"
  f0_amt = 29000
  f1_amt = 57202
  result = JSON.parse fund_0(addr, f0_amt), decimal_class: BigDecimal
  psbt = decode_psbt result['psbt']
  puts "decoded", JSON.pretty_generate(psbt)
  result = fund_1 addr, f1_amt, psbt
  puts result
end

run
