require 'date'
require 'roo-xls'

# this is a scrappy bit of code only to be used while testing, and nnot in production
# so ignore all lint errors
# rubocop:disable all

class LoadMeterDataFromCSV
  @@schools = {
      'Bathampton' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Bathampton.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Bathampton.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Batheaston' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Batheaston.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Batheaston.xls', fuel: 'Gas', worksheet: 'G2 AMR'}],
    'Bathford' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Bathford.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      # {  src: '2013 Energy Survey', type: 'xls', workbook: 'Bathford.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Bathford.xls', fuel: 'Gas', worksheet: 'G AMR'}],
    'Bathwick St Marys' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Bathwick St Marys.xls', fuel: 'Electricity', worksheet: 'E AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Bathwick St Marys.xls', fuel: 'Gas', worksheet: 'G AMR'}],
    'Bishop Sutton' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Bishop Sutton.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Bishop Sutton.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Bishop Sutton.xls', fuel: 'Gas', worksheet: 'G AMR'}],
    'Cameley' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Cameley.xls', fuel: 'Electricity', worksheet: 'E AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Cameley.xls', fuel: 'Gas', worksheet: 'G AMR'}],
    'Castle' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Castle.xls', fuel: 'Electricity', worksheet: 'E3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Castle.xls', fuel: 'Gas', worksheet: 'G AMR'}],
    'Chandag Juniors' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Chandag Juniors.xls', fuel: 'Electricity', worksheet: 'E AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Chandag Juniors.xls', fuel: 'Gas', worksheet: 'G AMR'}],
    'Chew Magna' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Chew Magna.xls', fuel: 'Electricity', worksheet: 'E AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Chew Magna.xls', fuel: 'Gas', worksheet: 'G AMR'}],
    'Chew Stoke' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Chew Stoke.xls', fuel: 'Gas', worksheet: 'G AMR'}],
    'Chew Valley' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Chew Valley.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Chew Valley.xls', fuel: 'Gas', worksheet: 'G2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Chew Valley.xls', fuel: 'Gas', worksheet: 'G3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Chew Valley.xls', fuel: 'Gas', worksheet: 'G4 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Chew Valley.xls', fuel: 'Gas', worksheet: 'G5 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Chew Valley.xls', fuel: 'Gas', worksheet: 'G6 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Chew Valley.xls', fuel: 'Gas', worksheet: 'G7 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Chew Valley.xls', fuel: 'Gas', worksheet: 'G8 AMR'}],
    'Clutton' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Clutton.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Clutton.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Clutton.xls', fuel: 'Electricity', worksheet: 'E3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Clutton.xls', fuel: 'Electricity', worksheet: 'E4 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Clutton.xls', fuel: 'Electricity', worksheet: 'E5 AMR'}],
    'Combe Down' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Combe Down.xls', fuel: 'Electricity', worksheet: 'E AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Combe Down.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Combe Down.xls', fuel: 'Gas', worksheet: 'G2 AMR'}],
    'East Harptree' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'East Harptree.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'East Harptree.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'East Harptree.xls', fuel: 'Gas', worksheet: 'G AMR'}],
    'Farmborough' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Farmborough.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Farmborough.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Farmborough.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Farrington Gurney' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Farrington Gurney.xls', fuel: 'Electricity', worksheet: 'E1 AMR'}],
    'Fosseway' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Fosseway.xls', fuel: 'Electricity', worksheet: 'E3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Fosseway.xls', fuel: 'Electricity', worksheet: 'E4 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Fosseway.xls', fuel: 'Electricity', worksheet: 'E5 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Fosseway.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Fosseway.xls', fuel: 'Gas', worksheet: 'G2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Fosseway.xls', fuel: 'Gas', worksheet: 'G3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Fosseway.xls', fuel: 'Gas', worksheet: 'G4 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Fosseway.xls', fuel: 'Gas', worksheet: 'G5 AMR'}],
    'Freshford' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Freshford.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Freshford.xls', fuel: 'Gas', worksheet: 'G2 AMR'}],
    'Hayesfield Lower' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Hayesfield Lower.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Hayesfield Lower.xls', fuel: 'Gas', worksheet: 'G2 AMR'}],
    'Hayesfield Upper' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Hayesfield Upper.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Hayesfield Upper.xls', fuel: 'Gas', worksheet: 'G2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Hayesfield Upper.xls', fuel: 'Gas', worksheet: 'G3 AMR'}],
    'Hayesfield VIth Form' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Hayesfield VIth Form.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'High Littleton' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'High Littleton.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'High Littleton.xls', fuel: 'Electricity', worksheet: 'E3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'High Littleton.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Longvernal' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Longvernal.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Longvernal.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Longvernal.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Marksbury' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Marksbury.xls', fuel: 'Electricity', worksheet: 'E1 AMR'}],
    'Midsomer Norton' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Midsomer Norton.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Midsomer Norton.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Moorland Infants' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Moorland Infants.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Moorland Juniors' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Moorland Juniors.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Moorland Juniors.xls', fuel: 'Gas', worksheet: 'G2 AMR'}],
    'Newbridge' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Newbridge.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Newbridge.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Newbridge.xls', fuel: 'Gas', worksheet: 'G2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Newbridge.xls', fuel: 'Gas', worksheet: 'G3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Newbridge.xls', fuel: 'Gas', worksheet: 'G4 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Newbridge.xls', fuel: 'Gas', worksheet: 'G5 AMR'}],
    'Norton Hill' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Norton Hill.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Norton Hill.xls', fuel: 'Gas', worksheet: 'G2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Norton Hill.xls', fuel: 'Gas', worksheet: 'G3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Norton Hill.xls', fuel: 'Gas', worksheet: 'G4 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Norton Hill.xls', fuel: 'Gas', worksheet: 'G5 AMR'}],
    'Oldfield Infant' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Oldfield Infant.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Oldfield Infant.xls', fuel: 'Gas', worksheet: 'G3 AMR'}],
    'Oldfield Junior' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Oldfield Junior.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Oldfield Junior.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Oldfield Junior.xls', fuel: 'Gas', worksheet: 'G2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Oldfield Junior.xls', fuel: 'Gas', worksheet: 'G3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Oldfield Junior.xls', fuel: 'Gas', worksheet: 'G4 AMR'}],
    'Paulton Infant' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Paulton Infant.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Paulton Junior' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Paulton Junior.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Peasedown' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Peasedown.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Peasedown.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Pensford' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Pensford.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Pensford.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Pensford.xls', fuel: 'Electricity', worksheet: 'E3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Pensford.xls', fuel: 'Electricity', worksheet: 'E4 AMR'}],
    'Ralp Allen' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Ralp Allen.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Ralp Allen.xls', fuel: 'Gas', worksheet: 'G2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Ralp Allen.xls', fuel: 'Gas', worksheet: 'G3 AMR'}],
    'Saltford' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Saltford.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Saltford.xls', fuel: 'Electricity', worksheet: 'E3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Saltford.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Somervale' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Somervale.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Somervale.xls', fuel: 'Gas', worksheet: 'G2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Somervale.xls', fuel: 'Gas', worksheet: 'G3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Somervale.xls', fuel: 'Gas', worksheet: 'G4 AMR'}],
    'Southdown Infants' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Southdown Infants.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Southdown Infants.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Southdown Infants.xls', fuel: 'Electricity', worksheet: 'E3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Southdown Infants.xls', fuel: 'Electricity', worksheet: 'E4 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Southdown Infants.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Southdown Infants.xls', fuel: 'Gas', worksheet: 'G2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Southdown Infants.xls', fuel: 'Gas', worksheet: 'G3 AMR'}],
    'Southdown Juniors' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Southdown Juniors.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Southdown Juniors.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Southdown Juniors.xls', fuel: 'Electricity', worksheet: 'E4 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Southdown Juniors.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Southdown Juniors.xls', fuel: 'Gas', worksheet: 'G2 AMR'}],
    'St Andrews' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Andrews.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'St Gregory\'s' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Gregory\'s.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Gregory\'s.xls', fuel: 'Gas', worksheet: 'G AMR'}],
    'St Johns Keynsham' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Johns Keynsham.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Johns Keynsham.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'St Johns MSN' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Johns MSN.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Johns MSN.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Johns MSN.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Johns MSN.xls', fuel: 'Gas', worksheet: 'G2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Johns MSN.xls', fuel: 'Gas', worksheet: 'G3 AMR'}],
    'St Julians' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Julians.xls', fuel: 'Electricity', worksheet: 'E1 AMR'}],
    'St Keyna' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Keyna.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Keyna.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'St Marks' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Marks.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Marks.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Marks.xls', fuel: 'Gas', worksheet: 'G2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Marks.xls', fuel: 'Gas', worksheet: 'G3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Marks.xls', fuel: 'Gas', worksheet: 'G4 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Marks.xls', fuel: 'Gas', worksheet: 'G5 AMR'}],
    'St Martins Garden' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Martins Garden.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Martins Garden.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Martins Garden.xls', fuel: 'Electricity', worksheet: 'E3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Martins Garden.xls', fuel: 'Electricity', worksheet: 'E4 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Martins Garden.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Martins Garden.xls', fuel: 'Gas', worksheet: 'G2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Martins Garden.xls', fuel: 'Gas', worksheet: 'G3 AMR'}],
    'St Marys Bath' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Marys Bath.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Marys Bath.xls', fuel: 'Gas', worksheet: 'G2 AMR'}],
    'St Marys Timsbury' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Marys Timsbury.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Marys Timsbury.xls', fuel: 'Electricity', worksheet: 'E3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Marys Timsbury.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'St Marys Writhlington' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Marys Writhlington.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'St Michaels' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Michaels.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Michaels.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Michaels.xls', fuel: 'Gas', worksheet: 'G2 AMR'}],
    'St Nicolas' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Nicolas.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Nicolas.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Nicolas.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'St Philips' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Philips.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Philips.xls', fuel: 'Gas', worksheet: 'G2 AMR'}],
    'St Saviours Infants' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Saviours Infants.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Saviours Infants.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'St Saviours Juniors' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Saviours Juniors.xls', fuel: 'Electricity', worksheet: 'E2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Saviours Juniors.xls', fuel: 'Electricity', worksheet: 'E3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Saviours Juniors.xls', fuel: 'Electricity', worksheet: 'E5 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Saviours Juniors.xls', fuel: 'Electricity', worksheet: 'E8 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Saviours Juniors.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Saviours Juniors.xls', fuel: 'Gas', worksheet: 'G2 AMR'}],
    'St Stephens' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Stephens.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'St Stephens.xls', fuel: 'Gas', worksheet: 'G2 AMR'}],
    'Stanton Drew' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Stanton Drew.xls', fuel: 'Electricity', worksheet: 'E1 AMR'}],
    'Swainswick' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Swainswick.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Swainswick.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'The Link' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'The Link.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'The Link.xls', fuel: 'Gas', worksheet: 'G2 AMR'}],
    'Threeways' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Threeways.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Twerton Infants' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Twerton Infants.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Twerton Infants.xls', fuel: 'Electricity', worksheet: 'E2 AMR'}],
    'Ubley' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Ubley.xls', fuel: 'Electricity', worksheet: 'E1 AMR'}],
    'Wellsway' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Wellsway.xls', fuel: 'Electricity', worksheet: 'E4 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Wellsway.xls', fuel: 'Electricity', worksheet: 'E6 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Wellsway.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Wellsway.xls', fuel: 'Gas', worksheet: 'G2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Wellsway.xls', fuel: 'Gas', worksheet: 'G3 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Wellsway.xls', fuel: 'Gas', worksheet: 'G4 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Wellsway.xls', fuel: 'Gas', worksheet: 'G5 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Wellsway.xls', fuel: 'Gas', worksheet: 'G6 AMR'}],
    'Welton' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Welton.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Welton.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Westfield' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Westfield.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Weston All Saints' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Weston All Saints.xls', fuel: 'Electricity', worksheet: 'E2 AMR'}],
    'Whitchurch' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Whitchurch.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Whitchurch.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Widcombe Infant' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Widcombe Infant.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Widcombe Infant.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Widcombe Junior' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Widcombe Junior.xls', fuel: 'Electricity', worksheet: 'E1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Widcombe Junior.xls', fuel: 'Gas', worksheet: 'G1 AMR'}],
    'Writhlington' =>  [ {  src: '2013 Energy Survey', type: 'xls', workbook: 'Writhlington.xls', fuel: 'Gas', worksheet: 'G1 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Writhlington.xls', fuel: 'Gas', worksheet: 'G2 AMR'},
      {  src: '2013 Energy Survey', type: 'xls', workbook: 'Writhlington.xls', fuel: 'Gas', worksheet: 'G3 AMR'}],
    'Bishop Sutton Primary School G' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathGas.xlsx', fuel: 'Gas', worksheet: 'Bishop Sutton Primary School G'}],
    'Castle Primary Gas Supply' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathGas.xlsx', fuel: 'Gas', worksheet: 'Castle Primary Gas Supply'}],
    'Freshford C of E Primary Schoo' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathGas.xlsx', fuel: 'Gas', worksheet: 'Freshford C of E Primary Schoo'}],
    'Infant School - Boilers-Heatin' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathGas.xlsx', fuel: 'Gas', worksheet: 'Infant School - Boilers-Heatin'}],
    'Infant School - Kitchen & Heat' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathGas.xlsx', fuel: 'Gas', worksheet: 'Infant School - Kitchen & Heat'}],
    'Infant School - The Hub' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathGas.xlsx', fuel: 'Gas', worksheet: 'Infant School - The Hub'}],
    'Junior School Gas - Kitchen' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathGas.xlsx', fuel: 'Gas', worksheet: 'Junior School Gas - Kitchen'}],
    'Junior School Gas Supply 2' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathGas.xlsx', fuel: 'Gas', worksheet: 'Junior School Gas Supply 2'}],
    'Paulton Junior School Gas Supp' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathGas.xlsx', fuel: 'Gas', worksheet: 'Paulton Junior School Gas Supp'}],
 #   'Saltford C of E Primary School' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathGas.xlsx', fuel: 'Gas', worksheet: 'Saltford C of E Primary School'}],
    'St Johns Catholic Primary Scho' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathGas.xlsx', fuel: 'Gas', worksheet: 'St Johns Catholic Primary Scho'}],
    'Twerton Infant School' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathGas.xlsx', fuel: 'Gas', worksheet: 'Twerton Infant School'}],
    '##Castle Primary School Electr' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: '##Castle Primary School Electr'}],
    'Bishop Sutton Primary School E' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Bishop Sutton Primary School E'}],
    'Castle Primary School (HH) (Ne' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Castle Primary School (HH) (Ne'}],
    'Castle Primary School Electric' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Castle Primary School Electric'}],
    'Freshford C of E Primary Elect' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Freshford C of E Primary Elect'}],
    'Infants School - Hot Water' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Infants School - Hot Water'}],
    'Infants School - Kitchen' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Infants School - Kitchen'}],
    'Infants School - Main School 1' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Infants School - Main School 1'}],
    'Infants School - Main School 2' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Infants School - Main School 2'}],
    'Junior School Electricity - Co' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Junior School Electricity - Co'}],
    'Junior School Electricity - Ki' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Junior School Electricity - Ki'}],
    'Keynsham Childrens Centre - Ca' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Keynsham Childrens Centre - Ca'}],
    'Marksbury C of E Primary Schoo' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Marksbury C of E Primary Schoo'}],
    'Paulton Junior School Electric' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Paulton Junior School Electric'}],
    'Pensford Primary Electricity S' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Pensford Primary Electricity S'}],
    'Pensford Primary School - Kitc' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Pensford Primary School - Kitc'}],
    'Radstock Library Electricity S' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Radstock Library Electricity S'}],
    'Saltford C of E Primary School' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Saltford C of E Primary School'}],
    'Saltford Library Electricity S' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Saltford Library Electricity S'}],
    'St Johns Primary (P272 HH)' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'St Johns Primary (P272 HH)'}],
    'St Johns Primary Oldfield Lane' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'St Johns Primary Oldfield Lane'}],
    'Stanton Drew Primary School (P' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Stanton Drew Primary School (P'}],
    'Twerton Infant School Electric' =>  [ {  src: 'Bath Hacked', type: 'xlsx', workbook: ' BathElectricity.xlsx', fuel: 'Electricity', worksheet: 'Twerton Infant School Electric'}]
  }

  def initialize(school)
    @school = school
  end

  def process_sheet(filename, sheet_name, sheet, date_col, data_col, first_data_row)
    data = AMRData.new("Unknown")
    row_count = 0
    amr_days = 0
    total_kwh = 0.0
    min_date = Date.new(2050,1,1)
    max_date = Date.new(2000,1,1)

    if sheet.last_row == nil
      puts "Empty Sheet #{sheet_name}"
      return
    end

    sheet.each do |row|
      if row_count > first_data_row
        amr_days += 1
        date = row[date_col]
        min_date = date < min_date ? date : min_date
        max_date = date > max_date ? date : max_date
        kwh_data = row[data_col..data_col + 47]
        data.add(date,kwh_data)
        total_kwh_today = kwh_data.inject(:+)
        total_kwh += total_kwh_today
      end
      row_count += 1
    end
    data
  end

  def load_meters()

    gas_meters, electric_meters = load_all_meters_for_school

    puts "Got #{gas_meters.length} gas meters and #{electric_meters.length} electicity meters"

    gas_meters.each do |name, data|
      meter = MeterAnalysis.new(name, data, :gas)
      @school.add_heat_meter(meter)
    end

    electric_meters.each do |name, data|
      meter = MeterAnalysis.new(name, data, :electricity)
      @school.add_electricity_meter(meter)
    end
  end

  private

  def load_all_meters_for_school
    electricity_meters = {}
    gas_meters = {}
    puts "Loading data for #{@school.name}"
    meters_for_school = @@schools[@school.name]
    meters_for_school.each do |meter|
        extension = meter[:type]
        filepath = if meter[:src] == 'Bath Hacked'
                      "F:\\OneDrive\\Documents\\Transition Bath\\Schools Energy Competition\\Ruby\\Examples\\EnergyData\\EnergySparks\\"
                    else
                      "F:\\OneDrive\\Documents\\Transition Bath\\Schools Energy Competition\\Ruby\\Examples\\EnergyData\\2013Data\\"
                    end
        filename = filepath + meter[:workbook]
        workbook = Roo::Spreadsheet.open(filename, extension: extension)
        worksheet =workbook.sheet(meter[:worksheet])

        if meter[:src] == 'Bath Hacked'
          data = process_sheet(filename, meter[:worksheet], worksheet, 1, 6, 1)
        else
          data = process_sheet(filename, meter[:worksheet], worksheet, 0, 3, 2)
        end
        if meter[:fuel] == 'Electricity'
          electricity_meters[meter[:worksheet]] = data
        else
          gas_meters[meter[:worksheet]] = data
        end
        puts meter.inspect
        puts "Got #{data.length} dates"
    end
    [gas_meters, electricity_meters]
  end
end
# rubocop:enable all
