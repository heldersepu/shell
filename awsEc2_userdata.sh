
declare -a arr=(
        "10.35.12.11"
        "10.35.12.53"
        "10.35.12.59"
        "10.35.12.80"
        "10.35.12.175"
        "10.35.12.179"
        "10.35.12.182"
        "10.35.12.242"
    )

RED='\033[0;31m'
GRN='\033[0;32m'
NC='\033[0m' # No Color

for i in "${arr[@]}"
do
    echo "${GRN}${i}${NC}"
    # https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-instances.html#options
    # ( pending | running | shutting-down | terminated | stopping | stopped )
    json=$(aws ec2 describe-instances --filters "Name=network-interface.addresses.private-ip-address,Values=${i}")
    arrids=($(echo $json | jq -r '.Reservations[].Instances[].InstanceId'))
    echo ""
    for id in "${arrids[@]}"
    do
        echo "${RED}${id}${NC}"
        data=$(aws ec2 describe-instance-attribute --instance-id ${id} --attribute userData | jq -r '.UserData.Value' | base64 --decode)

        if [[ $data = *"Content-Transfer-Encoding"* ]]; then
            echo "${RED}  Restart detected ${NC}"

            echo "" > temp_base64.txt
            #aws ec2 modify-instance-attribute --instance-id ${id} --attribute userData --value file://temp_base64.txt
            rm temp_base64.txt
        elif [[ $data = *"SSH_USERS"* ]]; then
            echo "${RED}  Single use detected ${NC}"

            echo "Content-Type: multipart/mixed; boundary=\"//\"" > temp.txt
            echo "MIME-Version: 1.0" >> temp.txt
            echo "" >> temp.txt
            echo "--//" >> temp.txt
            echo "Content-Type: text/cloud-config; charset=\"us-ascii\"" >> temp.txt
            echo "MIME-Version: 1.0" >> temp.txt
            echo "Content-Transfer-Encoding: 7bit" >> temp.txt
            echo "Content-Disposition: attachment; filename=\"cloud-config.txt\"" >> temp.txt
            echo "" >> temp.txt
            echo "#cloud-config" >> temp.txt
            echo "cloud_final_modules:" >> temp.txt
            echo "- [scripts-user, always]" >> temp.txt
            echo "" >> temp.txt
            echo "--//" >> temp.txt
            echo "Content-Type: text/x-shellscript; charset=\"us-ascii\"" >> temp.txt
            echo "MIME-Version: 1.0" >> temp.txt
            echo "Content-Transfer-Encoding: 7bit" >> temp.txt
            echo "Content-Disposition: attachment; filename=\"userdata.txt\"" >> temp.txt
            echo "" >> temp.txt
            echo "$data" >> temp.txt
            echo "--//" >> temp.txt
            base64 temp.txt > temp_base64.txt

            #aws ec2 modify-instance-attribute --instance-id ${id} --attribute userData --value file://temp_base64.txt
            rm temp_base64.txt
            rm temp.txt
        fi
    done
done