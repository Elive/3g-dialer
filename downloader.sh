#!/bin/bash
set -x
baseurl="http://iqonn.com/operators/"
file1="file1.html"
file2="file2.html"
#debug="yes"

fromline(){
   unset line
   line="$( grep -n "$2" "$1" | awk 'BEGIN {FS = ":"} {print $1}' )"
   echo "tail -n +$line"
   unset line
}
toline(){
   unset line
   line="$( grep -n "$2" "$1" | awk 'BEGIN {FS = ":"} {print $1}' )"
   echo "head -n +$line"
   unset line
}
debug(){
   [[ "$debug" != "yes" ]] && return 0
   echo -e "D: $1"
}


# get regions
curl -s "$baseurl" > $file1
cat $file1 | $( fromline "$file1" "Select your region:" ) > $file2
cat $file2 |  $( toline "$file2" "Select your country:" ) > $file1
regions="$( cat $file1 | sed "s|<a href|\n<a href|g" | grep "href=\"/operators/" | awk 'BEGIN {FS = "/"} {print $3}' | tr '\n' ' ' )"

# get country's
for region in $regions
do
   curl -s "${baseurl}${region}/" > $file1
   cat $file1 | $( fromline "$file1" "Select your country:" ) > $file2
   cat $file2 |  $( toline "$file2" "Supported operators:" ) > $file1
   countrys="$( cat $file1 | sed "s|<a href|\n<a href|g" | grep "href=\"/operators/" | awk 'BEGIN {FS = "/"} {print $3}' | tr '\n' ' ' ) $countrys"
done


# get templates
for country in $countrys
do
   unset subscription apn pass user operator
   debug "Country: $country"
   curl -s "${baseurl}${country}/" > $file1
   cat $file1 | $( fromline "$file1" "Supported operators:" ) > $file2
   cat $file2 |  $( toline "$file2" "submit_button.gif" ) > $file1
   cat $file1 | grep -q "We do not support any operator in" && continue
   cat $file1 | sed "s|<label|\n<label|g" > $file2
   cat $file2 | while read line
   do
#      if echo "$line" | grep -q "Incomplete settings" ; then
#      fi


      if echo "$line" | grep -q "^<label>" ; then
         line="${line#<label>}"
         firstparm="$( echo $line | sed 's|:.*$||g' )"
         case $firstparm in
         Subscription)
            subscription="${line##*label>}"
            subscription="${subscription%%</span>*}"
            subscription="$( echo $subscription )"
            echo "$subscription" | grep -qi "default" && unset subscription
            echo "$subscription" | grep -qi "internet" && unset subscription
            echo "$subscription" | grep -qi "predet" && unset subscription
            #debug "  subscription: $subscription"
            ;;
         APN)
            apn="${line##*label>}"
            apn="${apn%%</span>*}"
            apn="$( echo $apn )"
            echo "$apn" | grep -qE "(777|888)" && unset apn
            echo "$apn" | grep -q "none" && unset apn
            #debug "  apn: $apn"
            ;;
         Password)
            pass="${line##*label>}"
            pass="${pass%%</span>*}"
            pass="$( echo $pass )"
            echo "$pass" | grep -q "none" && unset pass
            #debug "  pass: $pass"
            ;;
         Username)
            user="${line##*label>}"
            user="${user%%</span>*}"
            user="$( echo $user )"
            echo "$user" | grep -q "none" && unset user
            #debug "  user: $user"

            # Save file:
            debug "  Saving: \n\t - C: $country | Op: $operator \n\t - Sub: $subscription | Apn: $apn \n\t - User: $user | Pass: $pass"
            if [[ -n "$country" && -n "$operator" && -n "$apn" ]] ; then
               mkdir -p templates_new
               if [[ -n "$subscription" ]] ; then
                  template="templates_new/${operator} - ${subscription}__${country}"
               else
                  template="templates_new/${operator}__${country}"
               fi
               touch "$template"
               [[ -n "$apn" ]] && echo -e "Apn=\"$apn\"" >> "$template"
               [[ -n "$user" ]] && echo -e "Username=\"$user\"" >> "$template"
               [[ -n "$pass" ]] && echo -e "Password=\"$pass\"" >> "$template"
               unset template
            else
               echo -e "E: Error saving file: \n\t - C: $country | Op: $operator \n\t - Sub: $subscription | Apn: $apn \n\t - User: $user | Pass: $pass"
            fi

            unset subscription apn user pass
            ;;
         *)
            debug "  OTHER: $firstparm | $line"
            ;;
         esac
      fi
      if echo "$line" | grep -q "href.*</a></b>" ; then

         operator="${line%</a>*}"
         operator="${operator##*>}"
         operator="${operator/$country/}"
         if echo "$operator" | grep -qiE "(vodafone|orange|\(|movistar|mobistar|^o2|telia|t-mobile|velcom|^tim|claro|cosmote|megafon|mobitel|^mts|^tigo)" ; then
            operator="$( echo "$operator" | awk '{print $1}')"
         fi
         operator="$( echo $operator )"
         #debug "  operator: $operator"
      fi
   done


done

rm -f "$file1" "$file2"


while read -ru 3 file
do
   cat "$file" | sort -u > "${file}.2"
   mv "${file}.2" "${file}"
done 3<<< "$( find "$(pwd)/templates_new/" -type f -iname '*'__'*' )"


echo -e "list of templates available at $(pwd)/templates_new/"

echo -e "\nNote: more providers can be found on this git: https://aur.archlinux.org/packages.php?ID=29530 | http://git.gnome.org/cgit/mobile-broadband-provider-info/"


