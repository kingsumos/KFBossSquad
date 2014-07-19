 <td></td>
 </tr>
 <tr><td colspan="15"><span class="location" title="Check this box to enable Bonus Stage. Leave this box unchecked for Boss Time">Bonus&nbsp;stage:&nbsp;</span><input type="checkbox" name="BonusStage" Value="True" <%Checked%>></td></tr>
 <tr><td colspan="15"><span class="location" title="The number of spawned monsters during Boss Time is calculated according to the number of alive players (determining a multiplier value).&#013;The multiplier value is increased per additional alive player, by summing the value of 'Scale Coefficient'.&#013;For example if 'Scale Coefficient' is 0.5: for one alive player the multiplier is 1.0; for two alive players the multiplier is 1.5; for three alive players the multiplier is 2.0.">Scale&nbsp;Coefficient:&nbsp;</span><input class=textbox type="text" name="PlayerCountScale" Value="<%PlayerCountScale%>" size="3" maxlength="5"</td></tr>
 <tr>
  <td colspan="15">
   <nobr>
   <input class="button" type="Submit" name="Update" Value="Update">
   <input class="button" type="Submit" name="Delete" Value="Delete">
   </nobr>
  </td>
 </tr>
</form>

