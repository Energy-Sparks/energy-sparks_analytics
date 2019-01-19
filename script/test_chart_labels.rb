require 'rubygems'
require 'write_xlsx'

workbook  = WriteXLSX.new( 'chart.xlsx' )
worksheet = workbook.add_worksheet

# Add the worksheet data the chart refers to.
data = [
    [ 'Category', 2, 3, 4, 5, 6, 7 ],
    [ 'Value',    1, 4, 5, 2, 1, 5 ],
    [ 1, 4, 5, 2, 1, 5 ]
    # [ 'Labels',   'dog', 'cat', 'pig', 'horse', 'cow', 'monkey' ]
]

worksheet.write( 'A1', data )

# Add a worksheet chart.
chart = workbook.add_chart( :type => 'column' )

# Configure the chart.
chart.add_series(
    :categories => '=Sheet1!$A$2:$A$7',
    :values     => '=Sheet1!$B$2:$B$7',
    :data_labels => '=Sheet1!$C$2:$C$7'
)

workbook.close
