# PSBT dual funding

``` sh
# Open channel via psbt
lncli openchannel --node_key <node-key> --local_amt 57202 --private --push_amt 15000 --psbt

# construct psbt
ruby psbt-fund.rb <funding addr>
```
