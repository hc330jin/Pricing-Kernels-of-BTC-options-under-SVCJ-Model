* Ref: https://github.com/QuantLet/Deribit_inverse_BTC_options/tree/main
* Code Revision: Chin HSU (hc330.sc14@nycu.edu.tw)
```
Deribit_inverse_BTC_options.m
└─ run_daily_*_calibration.m
   └─ calibrate_one_*_day.m
      ├─ make_daily_contract_base.m
      ├─ make_*_settings.m
      ├─ obj_lsqnonlin.m
      │  └─ calc_inverse.m
      │     ├─ calc_BS_inverse.m
      │     ├─ get_SV.m / get_SVJ.m / get_SVCJ.m
      │     └─ calc_payoff_inverse.m
      └─ make_*_result_row.m
└─ analyze_Q_results.m
```
# Q
Deribit_20220101.csv only contains Deribit options data for that day. 
## Main functions
| Index | Filename | Description |
| -------- | -------- | -------- |
| 1     | ```Deribit_inverse_BTC_options.m```     | Main file to estimate Q parameters|
|2|```estimate_Q_results.m```|Calculate descriptive statistics for Q parameters|
|3|```estimate_one_pk.m```|Main file to estimate density of p, q and pricing kernel|

## List of other functions
| Index | Filename | Decription |
| ------- | ------- | -------|
|1|```obj_fminsearch.m```|Minimize loss function for BS model|
|2|```obj_lsqnonlin.m```|Minimize loss function for SV, SVJ, SVCJ model|
|3|```calc_inverse.m```|To generate a price time series by estimated parameters|
|4|```calc_BS_inverse.m```|To calculate option price by BS formula|
|5|```get_SV.m```|Generate return and volatility path for SV model|
|6|```get_SVJ.m```|Generate return and volatility path for SVJ model|
|7|```get_SVCJ.m```|Generate return and volatility path for SVCJ model|
|8|```calc_payoff_inverse.m```|To calculate option price by from return series|
