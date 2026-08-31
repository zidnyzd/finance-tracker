package id.web.zira.app.adapters

import android.graphics.Color
import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import id.web.zira.app.databinding.ItemAccountBinding
import id.web.zira.app.databinding.ItemTransactionBinding
import id.web.zira.app.models.AccountModel
import id.web.zira.app.models.TxnModel

class AccountAdapter(
    private val list: List<AccountModel>,
    private val isBalanceHidden: Boolean = false
) : RecyclerView.Adapter<AccountAdapter.ViewHolder>() {

    class ViewHolder(val binding: ItemAccountBinding) : RecyclerView.ViewHolder(binding.root)

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemAccountBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val item = list[position]
        holder.binding.tvAccountName.text = item.name
        holder.binding.tvAccountBalance.text = if (isBalanceHidden) "Rp ••••••" else item.balanceStr
        holder.binding.tvAccountType.text = item.type.replaceFirstChar { it.uppercase() }

        try {
            holder.binding.viewColorDot.setBackgroundColor(Color.parseColor(item.colorHex ?: "#0284C7"))
        } catch (e: Exception) {
            holder.binding.viewColorDot.setBackgroundColor(Color.parseColor("#0284C7"))
        }
    }

    override fun getItemCount(): Int = list.size
}

class TransactionAdapter(
    private val list: List<TxnModel>,
    private val isBalanceHidden: Boolean = false,
    private val onItemClick: ((TxnModel) -> Unit)? = null
) : RecyclerView.Adapter<TransactionAdapter.ViewHolder>() {

    class ViewHolder(val binding: ItemTransactionBinding) : RecyclerView.ViewHolder(binding.root)

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemTransactionBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val item = list[position]
        holder.binding.tvTxnCategory.text = item.category
        val acct = item.accountName ?: "-"
        val desc = item.description ?: ""
        holder.binding.tvTxnDesc.text = if (desc.isNotEmpty()) "$desc • $acct" else acct
        holder.binding.tvTxnDate.text = item.humanDate

        val amountDisplay = if (isBalanceHidden) "Rp ••••••" else item.amountStr

        if (item.type == "income") {
            holder.binding.tvTxnAmount.text = "+ $amountDisplay"
            holder.binding.tvTxnAmount.setTextColor(Color.parseColor("#16A34A"))
            holder.binding.tvTxnIcon.text = "📈"
        } else {
            holder.binding.tvTxnAmount.text = "- $amountDisplay"
            holder.binding.tvTxnAmount.setTextColor(Color.parseColor("#DC2626"))
            holder.binding.tvTxnIcon.text = "📉"
        }

        holder.itemView.setOnClickListener {
            onItemClick?.invoke(item)
        }
    }

    override fun getItemCount(): Int = list.size
}
